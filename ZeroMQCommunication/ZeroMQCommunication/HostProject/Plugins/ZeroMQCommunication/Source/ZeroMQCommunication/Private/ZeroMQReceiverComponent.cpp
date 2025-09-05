#include "ZeroMQReceiverComponent.h"
#include "ZeroMQReceiverWorker.h"
#include "HAL/RunnableThread.h"
#include "Engine/World.h"
#include "TimerManager.h"

// ZeroMQ includes
#ifdef ZMQ_LIBRARY_AVAILABLE
#include "zmq.h"
#else
static void* zmq_ctx_new() { return nullptr; }
static int zmq_ctx_term(void*) { return 0; }
#endif

UZeroMQReceiverComponent::UZeroMQReceiverComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	ZMQContext = nullptr;
	SubscriberSocket = nullptr;
	Worker = nullptr;
	Thread = nullptr;
}

void UZeroMQReceiverComponent::BeginPlay()
{
	Super::BeginPlay();
	StartConnection();
}

void UZeroMQReceiverComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	StopConnection();
	Super::EndPlay(EndPlayReason);
}

void UZeroMQReceiverComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
}

void UZeroMQReceiverComponent::StartConnection()
{
	ZMQContext = zmq_ctx_new();
	if (!ZMQContext)
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to create ZeroMQ context for receiver component."));
		return;
	}

	Worker = new FZeroMQReceiverWorker(ZMQContext, ServerIP, Port, &MessageQueue);
	Thread = FRunnableThread::Create(Worker, *FString::Printf(TEXT("ZeroMQReceiverWorker_%s_%d"), *GetOwner()->GetName(), Port));

	if (GetWorld())
	{
		GetWorld()->GetTimerManager().SetTimer(ProcessMessagesTimer, this, &UZeroMQReceiverComponent::ProcessMessages, 0.05f, true);
	}
}

void UZeroMQReceiverComponent::StopConnection()
{
	if (GetWorld())
	{
		GetWorld()->GetTimerManager().ClearTimer(ProcessMessagesTimer);
	}

	if (Worker)
	{
		Worker->RequestStop();
	}

	if (Thread)
	{
		Thread->WaitForCompletion();
		delete Thread;
		Thread = nullptr;
	}

	if (Worker)
	{
		delete Worker;
		Worker = nullptr;
	}

	if (ZMQContext)
	{
		zmq_ctx_term(ZMQContext);
		ZMQContext = nullptr;
	}
}

void UZeroMQReceiverComponent::ProcessMessages()
{
	FCameraTransform Transform;
	while (MessageQueue.Dequeue(Transform))
	{
		OnTransformReceived.Broadcast(Transform);
	}
}
