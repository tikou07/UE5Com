#include "ZeroMQWorkerThread.h"
#include "ZeroMQCommunicationSubsystem.h"
#include "HAL/PlatformProcess.h"
#include "Misc/ScopeLock.h"

// ZeroMQ includes
#ifdef ZMQ_LIBRARY_AVAILABLE
#include "zmq.h"
#else
#include "ZeroMQStub.h"
#endif

FZeroMQWorkerThread::FZeroMQWorkerThread(
	void* InZMQContext,
	TMap<FString, FCameraConnection>* InCameraConnections,
	TQueue<TPair<FString, TArray<uint8>>, EQueueMode::Mpsc>* InImageQueue,
	FCriticalSection* InCriticalSection
)
	: ZMQContext(InZMQContext)
	, CameraConnections(InCameraConnections)
	, CriticalSection(InCriticalSection)
	, ImageQueue(InImageQueue)
	, bStopRequested(false)
	, bIsRunning(false)
{
}

FZeroMQWorkerThread::~FZeroMQWorkerThread()
{
	if (bIsRunning)
	{
		Stop();
	}
}

bool FZeroMQWorkerThread::Init()
{
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Worker Thread initializing..."));
	bIsRunning = true;
	return true;
}

uint32 FZeroMQWorkerThread::Run()
{
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Worker Thread started"));

	while (!bStopRequested)
	{
		ProcessImageQueue();
		FPlatformProcess::Sleep(LoopSleepTime);
	}

	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Worker Thread stopping"));
	return 0;
}

void FZeroMQWorkerThread::Stop()
{
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Worker Thread stop requested"));
	bStopRequested = true;
}

void FZeroMQWorkerThread::Exit()
{
	bIsRunning = false;
	UE_LOG(LogTemp, Log, TEXT("ZeroMQ Worker Thread exited"));
}

void FZeroMQWorkerThread::RequestStop()
{
	bStopRequested = true;
}

void FZeroMQWorkerThread::ProcessImageQueue()
{
	TPair<FString, TArray<uint8>> ImageData;
	while (ImageQueue && ImageQueue->Dequeue(ImageData))
	{
		FScopeLock Lock(CriticalSection);
		if (FCameraConnection* Connection = CameraConnections->Find(ImageData.Key))
		{
			if (!SendImageMessage(Connection->Socket, ImageData.Key, ImageData.Value))
			{
				UE_LOG(LogTemp, Warning, TEXT("Failed to send image for camera: %s"), *ImageData.Key);
			}
		}
		else
		{
			UE_LOG(LogTemp, Warning, TEXT("No active socket for camera: %s"), *ImageData.Key);
		}
	}
}

bool FZeroMQWorkerThread::SendImageMessage(void* Socket, const FString& CameraID, const TArray<uint8>& ImageData)
{
	if (!Socket) return false;

	// Send camera ID as topic
	FTCHARToUTF8 CameraIDConverter(*CameraID);
	if (zmq_send(Socket, CameraIDConverter.Get(), CameraIDConverter.Length(), ZMQ_SNDMORE) == -1)
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to send camera ID topic: %s"), UTF8_TO_TCHAR(zmq_strerror(zmq_errno())));
		return false;
	}

	// Send image data
	if (zmq_send(Socket, ImageData.GetData(), ImageData.Num(), 0) == -1)
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to send image data: %s"), UTF8_TO_TCHAR(zmq_strerror(zmq_errno())));
		return false;
	}

	UE_LOG(LogTemp, VeryVerbose, TEXT("Sent image for camera %s (%d bytes)"), *CameraID, ImageData.Num());
	return true;
}
