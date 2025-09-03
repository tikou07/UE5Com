#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/Texture2D.h"
#include "Engine/TextureRenderTarget2D.h"
#include "Components/SceneCaptureComponent2D.h"
#include "HAL/Runnable.h"
#include "HAL/RunnableThread.h"
#include "HAL/ThreadSafeBool.h"
#include "Containers/Queue.h"
#include "Http.h"
#include "ZeroMQCommunicationSubsystem.generated.h"

// ZeroMQ forward declarations
struct zmq_msg_t;

// Forward declarations
class FZeroMQWorkerThread;

USTRUCT(BlueprintType)
struct ZEROMQCOMMUNICATION_API FZeroMQSettings
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Settings")
	FString ServerIP = TEXT("127.0.0.1");

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Settings")
	int32 ImagePort = 5555;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Settings")
	int32 AckPort = 5559;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Settings")
	int32 ControlPort = 5556;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Settings")
	FIntPoint ImageResolution = FIntPoint(1024, 1024);

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Settings")
	float FrameRate = 1.0f;

	// If true, the Image publisher socket will bind to ImageAddress instead of connecting.
	// This allows UE5 to act as a client (connect) while the external process (MATLAB/Python)
	// binds and accepts the connection.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Settings")
	bool bImageBindMode = false;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Settings")
	bool bAutoConnect = true;
};

// Holds the ZeroMQ socket and related info for a single camera
struct FCameraConnection
{
	void* Socket;
	// Add other per-camera state if needed
};

USTRUCT(BlueprintType)
struct ZEROMQCOMMUNICATION_API FCameraTransform
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Camera Transform")
	FVector Location = FVector::ZeroVector;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Camera Transform")
	FRotator Rotation = FRotator::ZeroRotator;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Camera Transform")
	FString CameraID = TEXT("");
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCameraTransformReceived, const FCameraTransform&, Transform);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnImageSent, const FString&, CameraID, bool, bSuccess);

/**
 * ZeroMQ Communication Subsystem
 * Manages ZeroMQ connections and handles communication with external applications
 */
UCLASS()
class ZEROMQCOMMUNICATION_API UZeroMQCommunicationSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	// USubsystem interface
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// Connection Management
	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Communication")
	void StartConnection();

	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Communication")
	void StopConnection();

	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Communication")
	bool IsConnected() const { return bIsConnected; }

	// Actor Registration
	void RegisterCamera(class AZeroMQCameraActor* CameraActor);
	void UnregisterCamera(const FString& CameraID);

	// Image Sending
	void SendCameraImage(class AZeroMQCameraActor* CameraActor);

	// Settings
	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Communication")
	void UpdateSettings(const FZeroMQSettings& NewSettings);

	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Communication")
	FZeroMQSettings GetCurrentSettings() const { return CurrentSettings; }

	// Events for image sending

	UPROPERTY(BlueprintAssignable, Category = "ZeroMQ Communication")
	FOnImageSent OnImageSent;

private:
	// ZeroMQ Internal functions
	bool InitializeZeroMQ();
	void ShutdownZeroMQ();
	void SendImageViaZeroMQ(const FString& CameraID, const TArray<uint8>& ImageData);
	// Control messages are now handled by ZeroMQReceiverComponent
	TArray<uint8> ConvertRenderTargetToJPEG(UTextureRenderTarget2D* RenderTarget);
	TArray<uint8> ConvertRenderTargetToGrayscaleJPEG(UTextureRenderTarget2D* RenderTarget, const FVector& Coefficients);

	// HTTP-based functions (temporary compatibility)
	void InitializePythonHub();
	void ProcessIncomingMessages();
	void CheckForPendingCommands();
	void SendImageToPython(const FString& CameraID, const TArray<uint8>& ImageData);
	
	// HTTP callback
	void OnCommandReceived(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful);

	// ZeroMQ Context and Sockets
	void* ZMQContext;
	// Sockets are now managed per-camera
	// void* ImagePublisherSocket;
	// ControlSubscriberSocket is now managed by ZeroMQReceiverComponent
	void* AckPublisherSocket;      // PUB socket for sending ACKs back to Python

	// Worker thread for ZeroMQ message processing
	FZeroMQWorkerThread* WorkerThread;
	FRunnableThread* Thread;

	// Thread-safe queues for communication between game thread and worker thread
	TQueue<TPair<FString, TArray<uint8>>, EQueueMode::Mpsc> ImageQueue;
	// ControlQueue is now managed by ZeroMQReceiverComponent

	// Member variables
	UPROPERTY()
	FZeroMQSettings CurrentSettings;

	// Manages connections for each camera actor
	TMap<FString, FCameraConnection> CameraConnections;

	UPROPERTY()
	TMap<FString, class AActor*> RegisteredActors;

	FThreadSafeBool bIsConnected;
	FThreadSafeBool bShouldStop;
	
	// HTTP compatibility variables
	bool bPythonHubInitialized;

	// Timer for periodic operations
	FTimerHandle ImageSendingTimer;
	// ControlProcessingTimer is now managed by ZeroMQReceiverComponent

	// Critical section for thread safety
	mutable FCriticalSection CriticalSection;
};
