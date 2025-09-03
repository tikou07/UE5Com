#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ZeroMQCommunicationSubsystem.h"
#include "ZeroMQControlledActor.generated.h"

UCLASS(BlueprintType, Blueprintable)
class ZEROMQCOMMUNICATION_API AZeroMQControlledActor : public AActor
{
	GENERATED_BODY()
	
public:	
	// Sets default values for this actor's properties
	AZeroMQControlledActor();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:	
	// Called every frame
	virtual void Tick(float DeltaTime) override;

	// ZeroMQ Connection Settings
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Connection")
	FString ActorID = TEXT("Actor01");

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Connection")
	bool bAutoRegister = true;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Connection")
	FString ServerIP = TEXT("127.0.0.1");

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Connection")
	int32 Port = 5556;

	// Manual Control Functions
	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Actor")
	void SetActorTransformFromData(const FCameraTransform& Transform);

public:
	// Components
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	class UStaticMeshComponent* StaticMeshComponent;

private:
	// Event Handlers
	UFUNCTION()
	void OnTransformReceived(const FCameraTransform& Transform);

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

	// Delegate for transform received event
	DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnTransformReceived, const FCameraTransform&, Transform);
	UPROPERTY(BlueprintAssignable, Category = "ZeroMQ Events")
	FOnTransformReceived OnTransformReceivedDelegate;
};
