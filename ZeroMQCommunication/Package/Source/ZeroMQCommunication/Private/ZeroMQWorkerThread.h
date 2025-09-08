#pragma once

#include "CoreMinimal.h"
#include "HAL/Runnable.h"
#include "HAL/ThreadSafeBool.h"
#include "Containers/Queue.h"
#include "ZeroMQCommunicationSubsystem.h" // FCameraConnection と FCameraTransform の定義をインクルード

/**
 * ZeroMQ Worker Thread
 * Handles ZeroMQ communication in a separate thread to avoid blocking the game thread
 */
class FZeroMQWorkerThread : public FRunnable
{
public:
	FZeroMQWorkerThread(
		void* InZMQContext,
		TMap<FString, FCameraConnection>* InCameraConnections,
		TQueue<TPair<FString, TArray<uint8>>, EQueueMode::Mpsc>* InImageQueue,
		FCriticalSection* InCriticalSection
	);

	virtual ~FZeroMQWorkerThread();

	// FRunnable interface
	virtual bool Init() override;
	virtual uint32 Run() override;
	virtual void Stop() override;
	virtual void Exit() override;

	// Control functions
	void RequestStop();
	bool IsRunning() const { return bIsRunning; }

private:
	// ZeroMQ processing functions
	void ProcessImageQueue();
	bool SendImageMessage(void* Socket, const FString& CameraID, const TArray<uint8>& ImageData);

	// ZeroMQ context (owned by subsystem)
	void* ZMQContext;

	// Shared resources with subsystem
	TMap<FString, FCameraConnection>* CameraConnections;
	FCriticalSection* CriticalSection;

	// Queues for communication with main thread
	TQueue<TPair<FString, TArray<uint8>>, EQueueMode::Mpsc>* ImageQueue;

	// Thread control
	FThreadSafeBool bStopRequested;
	FThreadSafeBool bIsRunning;

	// Timing
	static constexpr float LoopSleepTime = 0.001f; // 1ms sleep between iterations
};
