#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "ZeroMQCommunicationSubsystem.h" // For FCameraTransform
#include "ZeroMQReceiverComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnTransformReceivedComponent, const FCameraTransform&, Transform);

UCLASS( ClassGroup=(Custom), meta=(BlueprintSpawnableComponent) )
class ZEROMQCOMMUNICATION_API UZeroMQReceiverComponent : public UActorComponent
{
	GENERATED_BODY()

public:	
	UZeroMQReceiverComponent();

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:	
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	// ZeroMQ Connection Settings
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Connection")
	FString ServerIP = TEXT("127.0.0.1");

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Connection")
	int32 Port = 5556;

	// Events
	UPROPERTY(BlueprintAssignable, Category = "ZeroMQ Events")
	FOnTransformReceivedComponent OnTransformReceived;

private:
	void StartConnection();
	void StopConnection();
	void ProcessMessages();

	// ZeroMQ Context and Socket
	void* ZMQContext;
	void* SubscriberSocket;

	// Worker thread
	class FZeroMQReceiverWorker* Worker;
	class FRunnableThread* Thread;

	// Thread-safe queue for messages
	TQueue<FCameraTransform, EQueueMode::Mpsc> MessageQueue;

	FTimerHandle ProcessMessagesTimer;
};
