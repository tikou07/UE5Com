#pragma once

#include "CoreMinimal.h"
#include "Camera/CameraActor.h"
#include "Components/SceneCaptureComponent2D.h"
#include "Engine/TextureRenderTarget2D.h"
#include "ZeroMQCommunicationSubsystem.h"
#include "ZeroMQCameraActor.generated.h"

UENUM(BlueprintType)
enum class EImageFormatMode : uint8
{
	Color	UMETA(DisplayName = "Color"),
	Grayscale UMETA(DisplayName = "Grayscale")
};

/**
 * ZeroMQ Camera Actor
 * A specialized camera actor that can capture images and send them via ZeroMQ
 * Also receives position and rotation commands from external applications
 */
UCLASS(BlueprintType, Blueprintable)
class ZEROMQCOMMUNICATION_API AZeroMQCameraActor : public ACameraActor
{
	GENERATED_BODY()

public:
	AZeroMQCameraActor();

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:
	virtual void Tick(float DeltaTime) override;

	// Camera Settings
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Camera")
	FString CameraID = TEXT("Camera01");

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Camera")
	bool bAutoRegister = true;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Camera")
	bool bEnableImageCapture = true;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Camera")
	float ImageCaptureInterval = 1.0f; // seconds

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Camera")
	FIntPoint CaptureResolution = FIntPoint(1024, 1024);

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Camera")
	EImageFormatMode ImageFormat = EImageFormatMode::Color;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Camera", meta = (EditCondition = "ImageFormat == EImageFormatMode::Grayscale", ToolTip = "Coefficients for RGB to Grayscale conversion."))
	FVector GrayscaleCoefficients = FVector(0.299f, 0.587f, 0.114f);

	// ZeroMQ Connection Settings
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Connection")
	int32 ImagePort = 5555;

	// When true, UE5 will bind the image publisher socket (listen) instead of connecting.
	// Exposed in the Details panel so users can toggle per-camera.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ZeroMQ Connection", meta = (EditCondition = "bUseCustomSettings", ToolTip = "If true, UE5 will bind the image publisher socket (listen); otherwise it will connect."))
	bool bImageBindMode = true;

	// Manual Control Functions
	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Camera")
	void CaptureAndSendImage();

	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Camera")
	void SetCameraTransform(const FCameraTransform& Transform);

	UFUNCTION(BlueprintCallable, Category = "ZeroMQ Camera")
	FCameraTransform GetCameraTransform() const;

	// Event Handlers
	UFUNCTION()
	void OnTransformReceived(const FCameraTransform& Transform);

public:
	// Components
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	class USceneCaptureComponent2D* SceneCaptureComponent;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	class UTextureRenderTarget2D* RenderTarget;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	class UZeroMQReceiverComponent* ZeroMQReceiverComponent;

protected:

	// Internal functions
	void InitializeRenderTarget();
	void SetupSceneCapture();
	void StartImageCapture();
	void StopImageCapture();

private:
	// Timer for image capture
	FTimerHandle ImageCaptureTimer;

	// Subsystem reference
	UPROPERTY()
	class UZeroMQCommunicationSubsystem* CommunicationSubsystem;

	// State tracking
	float LastCaptureTime = 0.0f;
};
