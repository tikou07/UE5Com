#include "ZeroMQCommunicationSubsystem.h"
#include "ZeroMQCameraActor.h"
#include "ZeroMQWorkerThread.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "Engine/TextureRenderTarget.h"
#include "TextureResource.h"
#include "TimerManager.h"
#include "ImageUtils.h"
#include "IImageWrapper.h"
#include "IImageWrapperModule.h"
#include "Modules/ModuleManager.h"
#include "HAL/RunnableThread.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Misc/ScopeLock.h"

// ZeroMQ includes
#ifdef ZMQ_LIBRARY_AVAILABLE
#include "zmq.h"
#else
#include "ZeroMQStub.h"
#endif

void UZeroMQCommunicationSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Communication Subsystem Initializing..."));

	ZMQContext = nullptr;
	WorkerThread = nullptr;
	Thread = nullptr;
	bIsConnected = false;

	// Auto-connect if enabled in settings
	if (FZeroMQSettings().bAutoConnect)
	{
		StartConnection();
	}
}

void UZeroMQCommunicationSubsystem::Deinitialize()
{
	StopConnection();
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Communication Subsystem Deinitialized"));
	Super::Deinitialize();
}

void UZeroMQCommunicationSubsystem::StartConnection()
{
	if (bIsConnected)
	{
		UE_LOG(LogTemp, Warning, TEXT("ZeroMQ subsystem already started."));
		return;
	}

	if (!InitializeZeroMQ())
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to initialize ZeroMQ subsystem."));
		return;
	}

	// Worker thread now manages multiple sockets, so we pass the connections map
	WorkerThread = new FZeroMQWorkerThread(ZMQContext, &CameraConnections, &ImageQueue, &CriticalSection);
	Thread = FRunnableThread::Create(WorkerThread, TEXT("ZeroMQWorkerThread"));

	if (!Thread)
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to create ZeroMQ worker thread."));
		delete WorkerThread;
		WorkerThread = nullptr;
		ShutdownZeroMQ();
		return;
	}

	bIsConnected = true;
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Communication Subsystem Started."));
}

void UZeroMQCommunicationSubsystem::StopConnection()
{
	if (!bIsConnected)
	{
		return;
	}

	if (WorkerThread)
	{
		WorkerThread->RequestStop();
	}

	if (Thread)
	{
		Thread->WaitForCompletion();
		delete Thread;
		Thread = nullptr;
	}

	if (WorkerThread)
	{
		delete WorkerThread;
		WorkerThread = nullptr;
	}

	ShutdownZeroMQ(); // This will close all sockets and the context

	bIsConnected = false;
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Communication Subsystem Stopped."));
}

void UZeroMQCommunicationSubsystem::RegisterCamera(AZeroMQCameraActor* CameraActor)
{
	if (!bIsConnected || !CameraActor) return;

	const FString CameraID = CameraActor->CameraID;
	if (CameraConnections.Contains(CameraID))
	{
		UE_LOG(LogTemp, Warning, TEXT("Camera %s is already registered."), *CameraID);
		return;
	}

	void* NewSocket = zmq_socket(ZMQContext, ZMQ_PUB);
	if (!NewSocket)
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to create socket for camera %s: %s"), *CameraID, UTF8_TO_TCHAR(zmq_strerror(zmq_errno())));
		return;
	}

	FString Address = FString::Printf(TEXT("tcp://*:%d"), CameraActor->ImagePort);
	if (!CameraActor->bImageBindMode)
	{
		// Connect instead of bind
		Address = FString::Printf(TEXT("tcp://%s:%d"), *CurrentSettings.ServerIP, CameraActor->ImagePort);
	}

	FTCHARToUTF8 AddressConverter(*Address);
	int Result = -1;
	if (CameraActor->bImageBindMode)
	{
		Result = zmq_bind(NewSocket, AddressConverter.Get());
	}
	else
	{
		Result = zmq_connect(NewSocket, AddressConverter.Get());
	}

	if (Result != 0)
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to %s socket for camera %s at %s: %s"),
			CameraActor->bImageBindMode ? TEXT("bind") : TEXT("connect"),
			*CameraID, *Address, UTF8_TO_TCHAR(zmq_strerror(zmq_errno())));
		zmq_close(NewSocket);
		return;
	}

	{
		FScopeLock Lock(&CriticalSection);
		CameraConnections.Add(CameraID, { NewSocket });
	}

	UE_LOG(LogTemp, Log, TEXT("Camera %s registered and socket %s to %s."),
		*CameraID,
		CameraActor->bImageBindMode ? TEXT("bound") : TEXT("connected"),
		*Address);
}

void UZeroMQCommunicationSubsystem::UnregisterCamera(const FString& CameraID)
{
	if (!bIsConnected) return;

	FScopeLock Lock(&CriticalSection);
	if (FCameraConnection* Connection = CameraConnections.Find(CameraID))
	{
		zmq_close(Connection->Socket);
		CameraConnections.Remove(CameraID);
		UE_LOG(LogTemp, Log, TEXT("Camera %s unregistered and socket closed."), *CameraID);
	}
}


void UZeroMQCommunicationSubsystem::SendCameraImage(AZeroMQCameraActor* CameraActor)
{
	if (!bIsConnected || !CameraActor || !CameraActor->RenderTarget)
	{
		if (CameraActor)
		{
			OnImageSent.Broadcast(CameraActor->CameraID, false);
		}
		return;
	}

	TArray<uint8> ImageData;
	if (CameraActor->ImageFormat == EImageFormatMode::Grayscale)
	{
		ImageData = ConvertRenderTargetToGrayscaleJPEG(CameraActor->RenderTarget, CameraActor->GrayscaleCoefficients);
	}
	else
	{
		ImageData = ConvertRenderTargetToJPEG(CameraActor->RenderTarget);
	}

	if (ImageData.Num() > 0)
	{
		SendImageToPython(CameraActor->CameraID, ImageData);
		OnImageSent.Broadcast(CameraActor->CameraID, true);
	}
	else
	{
		OnImageSent.Broadcast(CameraActor->CameraID, false);
	}
}

void UZeroMQCommunicationSubsystem::UpdateSettings(const FZeroMQSettings& NewSettings)
{
	// Global settings update. Note that per-camera settings like port and bind mode
	// are now managed by the camera actor itself. Re-registering cameras might be
	// necessary if server IPs change.
	CurrentSettings = NewSettings;
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ global settings updated. Server IP is now %s."), *CurrentSettings.ServerIP);
}

void UZeroMQCommunicationSubsystem::InitializePythonHub()
{
	// For now, we'll use HTTP communication as a placeholder
	// In a full implementation, this would start the Python hub process
	// and establish ZeroMQ connections
	
	UE_LOG(LogTemp, Warning, TEXT("Initializing Python Hub (HTTP placeholder)"));
	bPythonHubInitialized = true;
}

void UZeroMQCommunicationSubsystem::ProcessIncomingMessages()
{
	if (!bIsConnected || !bPythonHubInitialized)
	{
		return;
	}
	
	// Poll for incoming HTTP commands from Python Hub
	// In a real implementation, this would be handled by a proper HTTP server
	// For now, we'll check for pending commands via HTTP GET request
	
	static float LastCommandCheck = 0.0f;
	float CurrentTime = GetWorld()->GetTimeSeconds();
	
	// Check for commands every 0.5 seconds to avoid overwhelming the server
	if (CurrentTime - LastCommandCheck > 0.5f)
	{
		LastCommandCheck = CurrentTime;
		CheckForPendingCommands();
	}
}

void UZeroMQCommunicationSubsystem::CheckForPendingCommands()
{
	// Create HTTP request to check for pending commands
	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL(FString::Printf(TEXT("http://%s:8080/get_pending_commands"), *CurrentSettings.ServerIP));
	Request->SetVerb(TEXT("GET"));
	Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
	
	Request->OnProcessRequestComplete().BindUObject(this, &UZeroMQCommunicationSubsystem::OnCommandReceived);
	Request->ProcessRequest();
}

void UZeroMQCommunicationSubsystem::OnCommandReceived(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful)
{
	if (!bWasSuccessful || !Response.IsValid())
	{
		return;
	}
	
	FString ResponseString = Response->GetContentAsString();
	if (ResponseString.IsEmpty())
	{
		return;
	}
	
	// Parse JSON response
	TSharedPtr<FJsonObject> JsonObject;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseString);
	
	if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
	{
		// Check if this is a camera transform command
		FString CommandType;
		if (JsonObject->TryGetStringField(TEXT("type"), CommandType) && CommandType == TEXT("camera_transform"))
		{
			FCameraTransform Transform;
			
			// Get camera ID
			JsonObject->TryGetStringField(TEXT("camera_id"), Transform.CameraID);
			
			// Get location
			if (const TSharedPtr<FJsonObject>* LocationObj = nullptr; JsonObject->TryGetObjectField(TEXT("location"), LocationObj))
			{
				double X = 0, Y = 0, Z = 0;
				(*LocationObj)->TryGetNumberField(TEXT("x"), X);
				(*LocationObj)->TryGetNumberField(TEXT("y"), Y);
				(*LocationObj)->TryGetNumberField(TEXT("z"), Z);
				Transform.Location = FVector(X, Y, Z);
			}
			
			// Get rotation
			if (const TSharedPtr<FJsonObject>* RotationObj = nullptr; JsonObject->TryGetObjectField(TEXT("rotation"), RotationObj))
			{
				double Pitch = 0, Yaw = 0, Roll = 0;
				(*RotationObj)->TryGetNumberField(TEXT("pitch"), Pitch);
				(*RotationObj)->TryGetNumberField(TEXT("yaw"), Yaw);
				(*RotationObj)->TryGetNumberField(TEXT("roll"), Roll);
				Transform.Rotation = FRotator(Pitch, Yaw, Roll);
			}
			
			UE_LOG(LogTemp, Warning, TEXT("Received camera transform command for %s: Location(%f,%f,%f) Rotation(%f,%f,%f)"), 
				*Transform.CameraID, 
				Transform.Location.X, Transform.Location.Y, Transform.Location.Z,
				Transform.Rotation.Pitch, Transform.Rotation.Yaw, Transform.Rotation.Roll);
			
			// This is now handled by ZeroMQReceiverComponent
		}
	}
}

bool UZeroMQCommunicationSubsystem::InitializeZeroMQ()
{
	UE_LOG(LogTemp, Log, TEXT("Initializing ZeroMQ Context..."));
	ZMQContext = zmq_ctx_new();
	if (!ZMQContext)
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to create ZeroMQ context: %s"), UTF8_TO_TCHAR(zmq_strerror(zmq_errno())));
		return false;
	}
	// Individual sockets are now created in RegisterCamera
	return true;
}

void UZeroMQCommunicationSubsystem::ShutdownZeroMQ()
{
	UE_LOG(LogTemp, Log, TEXT("Shutting down ZeroMQ..."));

	// Close all camera sockets
	{
		FScopeLock Lock(&CriticalSection);
		for (auto& Elem : CameraConnections)
		{
			zmq_close(Elem.Value.Socket);
		}
		CameraConnections.Empty();
	}

	// Terminate context
	if (ZMQContext)
	{
		zmq_ctx_term(ZMQContext);
		ZMQContext = nullptr;
	}

	UE_LOG(LogTemp, Log, TEXT("ZeroMQ shutdown complete."));
}

void UZeroMQCommunicationSubsystem::SendImageViaZeroMQ(const FString& CameraID, const TArray<uint8>& ImageData)
{
	if (!bIsConnected)
	{
		return;
	}
	
	// Enqueue image data for worker thread to process
	ImageQueue.Enqueue(TPair<FString, TArray<uint8>>(CameraID, ImageData));
	
	UE_LOG(LogTemp, VeryVerbose, TEXT("Queued image from camera %s (%d bytes)"), *CameraID, ImageData.Num());
}


void UZeroMQCommunicationSubsystem::SendImageToPython(const FString& CameraID, const TArray<uint8>& ImageData)
{
	// Use ZeroMQ for sending image data
	SendImageViaZeroMQ(CameraID, ImageData);
}

TArray<uint8> UZeroMQCommunicationSubsystem::ConvertRenderTargetToJPEG(UTextureRenderTarget2D* RenderTarget)
{
	TArray<uint8> Result;
	
	if (!RenderTarget)
	{
		return Result;
	}
	
	// Read pixels from render target
	auto* RenderTargetResource = RenderTarget->GameThread_GetRenderTargetResource();
	if (!RenderTargetResource)
	{
		return Result;
	}
	
	TArray<FColor> SurfaceData;
	if (!RenderTargetResource->ReadPixels(SurfaceData))
	{
		return Result;
	}
	
	// Convert to JPEG using ImageWrapper
	IImageWrapperModule& ImageWrapperModule = FModuleManager::LoadModuleChecked<IImageWrapperModule>(FName("ImageWrapper"));
	TSharedPtr<IImageWrapper> ImageWrapper = ImageWrapperModule.CreateImageWrapper(EImageFormat::JPEG);
	
	if (ImageWrapper.IsValid())
	{
		const int32 Width = RenderTarget->SizeX;
		const int32 Height = RenderTarget->SizeY;
		
		if (ImageWrapper->SetRaw(SurfaceData.GetData(), SurfaceData.Num() * sizeof(FColor), Width, Height, ERGBFormat::BGRA, 8))
		{
			const TArray64<uint8>& CompressedData = ImageWrapper->GetCompressed(85); // 85% quality
			Result.Append(CompressedData.GetData(), CompressedData.Num());
		}
	}
	
	return Result;
}

TArray<uint8> UZeroMQCommunicationSubsystem::ConvertRenderTargetToGrayscaleJPEG(UTextureRenderTarget2D* RenderTarget, const FVector& Coefficients)
{
	TArray<uint8> Result;

	if (!RenderTarget)
	{
		return Result;
	}

	auto* RenderTargetResource = RenderTarget->GameThread_GetRenderTargetResource();
	if (!RenderTargetResource)
	{
		return Result;
	}

	TArray<FColor> SurfaceData;
	if (!RenderTargetResource->ReadPixels(SurfaceData))
	{
		return Result;
	}

	// Convert to Grayscale
	TArray<FColor> GrayscaleData;
	GrayscaleData.SetNum(SurfaceData.Num());
	for (int32 i = 0; i < SurfaceData.Num(); ++i)
	{
		const FColor& Color = SurfaceData[i];
		uint8 Gray = static_cast<uint8>(Coefficients.X * Color.R + Coefficients.Y * Color.G + Coefficients.Z * Color.B);
		GrayscaleData[i] = FColor(Gray, Gray, Gray, Color.A);
	}

	// Convert to JPEG
	IImageWrapperModule& ImageWrapperModule = FModuleManager::LoadModuleChecked<IImageWrapperModule>(FName("ImageWrapper"));
	TSharedPtr<IImageWrapper> ImageWrapper = ImageWrapperModule.CreateImageWrapper(EImageFormat::JPEG);

	if (ImageWrapper.IsValid())
	{
		const int32 Width = RenderTarget->SizeX;
		const int32 Height = RenderTarget->SizeY;

		if (ImageWrapper->SetRaw(GrayscaleData.GetData(), GrayscaleData.Num() * sizeof(FColor), Width, Height, ERGBFormat::BGRA, 8))
		{
			const TArray64<uint8>& CompressedData = ImageWrapper->GetCompressed(85); // 85% quality
			Result.Append(CompressedData.GetData(), CompressedData.Num());
		}
	}

	return Result;
}
