#pragma once

#include "CoreMinimal.h"
#include "HAL/Runnable.h"
#include "HAL/ThreadSafeBool.h"
#include "Containers/Queue.h"
#include "ZeroMQCommunicationSubsystem.h" // For FCameraTransform

class FZeroMQReceiverWorker : public FRunnable
{
public:
	FZeroMQReceiverWorker(void* InContext, const FString& InServerIP, int32 InPort, TQueue<FCameraTransform, EQueueMode::Mpsc>* InQueue);
	virtual ~FZeroMQReceiverWorker();

	// FRunnable interface
	virtual bool Init() override;
	virtual uint32 Run() override;
	virtual void Stop() override;
	virtual void Exit() override;

	void RequestStop();

private:
	void* ZMQContext;
	void* SubscriberSocket;
	FString ServerIP;
	int32 Port;
	TQueue<FCameraTransform, EQueueMode::Mpsc>* MessageQueue;
	FThreadSafeBool bShouldStop;
};
