#include "ZeroMQControlledActor.h"
#include "Components/StaticMeshComponent.h"
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

// Sets default values
AZeroMQControlledActor::AZeroMQControlledActor()
{
 	// Set this actor to call Tick() every frame.  You can turn this off to improve performance if you don't need it.
	PrimaryActorTick.bCanEverTick = true;

	StaticMeshComponent = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("StaticMeshComponent"));
	RootComponent = StaticMeshComponent;

	ZMQContext = nullptr;
	SubscriberSocket = nullptr;
	Worker = nullptr;
	Thread = nullptr;
}

// Called when the game starts or when spawned
void AZeroMQControlledActor::BeginPlay()
{
	Super::BeginPlay();
	
	OnTransformReceivedDelegate.AddDynamic(this, &AZeroMQControlledActor::OnTransformReceived);
	StartConnection();
}

void AZeroMQControlledActor::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	OnTransformReceivedDelegate.RemoveDynamic(this, &AZeroMQControlledActor::OnTransformReceived);
	StopConnection();
	Super::EndPlay(EndPlayReason);
}

// Called every frame
void AZeroMQControlledActor::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
}

void AZeroMQControlledActor::SetActorTransformFromData(const FCameraTransform& Transform)
{
	SetActorLocation(Transform.Location);
	SetActorRotation(Transform.Rotation);

	UE_LOG(LogTemp, Log, TEXT("Actor %s transform updated: Location=%s, Rotation=%s"),
		*ActorID, *Transform.Location.ToString(), *Transform.Rotation.ToString());
}

void AZeroMQControlledActor::OnTransformReceived(const FCameraTransform& Transform)
{
	if (Transform.CameraID == ActorID || Transform.CameraID.IsEmpty())
	{
		SetActorTransformFromData(Transform);
	}
}

void AZeroMQControlledActor::StartConnection()
{
	ZMQContext = zmq_ctx_new();
	if (!ZMQContext)
	{
		UE_LOG(LogTemp, Error, TEXT("Failed to create ZeroMQ context for receiver component."));
		return;
	}

	Worker = new FZeroMQReceiverWorker(ZMQContext, ServerIP, Port, &MessageQueue);
	Thread = FRunnableThread::Create(Worker, *FString::Printf(TEXT("ZeroMQReceiverWorker_%s_%d"), *GetName(), Port));

	if (GetWorld())
	{
		GetWorld()->GetTimerManager().SetTimer(ProcessMessagesTimer, this, &AZeroMQControlledActor::ProcessMessages, 0.016f, true);
	}
}

void AZeroMQControlledActor::StopConnection()
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

void AZeroMQControlledActor::ProcessMessages()
{
	FCameraTransform Transform;
	while (MessageQueue.Dequeue(Transform))
	{
		OnTransformReceivedDelegate.Broadcast(Transform);
	}
}
