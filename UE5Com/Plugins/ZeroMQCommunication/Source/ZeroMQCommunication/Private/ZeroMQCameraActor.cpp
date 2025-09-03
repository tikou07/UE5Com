#include "ZeroMQCameraActor.h"
#include "ZeroMQCommunicationSubsystem.h"
#include "ZeroMQReceiverComponent.h"
#include "Components/SceneCaptureComponent2D.h"
#include "Engine/TextureRenderTarget2D.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "TimerManager.h"
#include "Camera/CameraComponent.h"

AZeroMQCameraActor::AZeroMQCameraActor()
{
	PrimaryActorTick.bCanEverTick = true;
	
	// Create scene capture component
	SceneCaptureComponent = CreateDefaultSubobject<USceneCaptureComponent2D>(TEXT("SceneCaptureComponent"));
	SceneCaptureComponent->SetupAttachment(GetCameraComponent());
	
	// Set default capture settings
	SceneCaptureComponent->CaptureSource = SCS_FinalColorLDR;
	SceneCaptureComponent->bCaptureEveryFrame = false; // We'll capture manually
	SceneCaptureComponent->bCaptureOnMovement = false;

	ZeroMQReceiverComponent = CreateDefaultSubobject<UZeroMQReceiverComponent>(TEXT("ZeroMQReceiverComponent"));
}

void AZeroMQCameraActor::BeginPlay()
{
	Super::BeginPlay();

	InitializeRenderTarget();
	SetupSceneCapture();

	if (UGameInstance* GameInstance = GetGameInstance())
	{
		CommunicationSubsystem = GameInstance->GetSubsystem<UZeroMQCommunicationSubsystem>();
	}

	if (CommunicationSubsystem && bAutoRegister)
	{
		CommunicationSubsystem->RegisterCamera(this);
	}

	if (ZeroMQReceiverComponent)
	{
		ZeroMQReceiverComponent->OnTransformReceived.AddDynamic(this, &AZeroMQCameraActor::OnTransformReceived);
	}

	if (bEnableImageCapture)
	{
		StartImageCapture();
	}
}

void AZeroMQCameraActor::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	StopImageCapture();

	if (CommunicationSubsystem && bAutoRegister)
	{
		CommunicationSubsystem->UnregisterCamera(CameraID);
	}

	Super::EndPlay(EndPlayReason);
}

void AZeroMQCameraActor::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	
	// Update last capture time tracking
	LastCaptureTime += DeltaTime;
}

void AZeroMQCameraActor::CaptureAndSendImage()
{
	if (!bEnableImageCapture || !SceneCaptureComponent || !RenderTarget || !CommunicationSubsystem)
	{
		return;
	}
	
	// Check if enough time has passed since last capture
	if (LastCaptureTime < ImageCaptureInterval)
	{
		return;
	}
	
	// Capture the scene
	SceneCaptureComponent->CaptureScene();
	
	// Send the image
	CommunicationSubsystem->SendCameraImage(this);
	
	// Reset capture time
	LastCaptureTime = 0.0f;
	
	UE_LOG(LogTemp, VeryVerbose, TEXT("Camera %s captured and sent image"), *CameraID);
}

void AZeroMQCameraActor::SetCameraTransform(const FCameraTransform& Transform)
{
	if (Transform.CameraID == CameraID || Transform.CameraID.IsEmpty())
	{
		SetActorLocation(Transform.Location);
		SetActorRotation(Transform.Rotation);
		
		UE_LOG(LogTemp, Log, TEXT("Camera %s transform updated: Location=%s, Rotation=%s"), 
			*CameraID, *Transform.Location.ToString(), *Transform.Rotation.ToString());
	}
}

FCameraTransform AZeroMQCameraActor::GetCameraTransform() const
{
	FCameraTransform Transform;
	Transform.CameraID = CameraID;
	Transform.Location = GetActorLocation();
	Transform.Rotation = GetActorRotation();
	return Transform;
}


void AZeroMQCameraActor::OnTransformReceived(const FCameraTransform& Transform)
{
	// Only respond to transforms for this camera or broadcast transforms
	if (Transform.CameraID == CameraID || Transform.CameraID.IsEmpty())
	{
		SetCameraTransform(Transform);
	}
}

void AZeroMQCameraActor::InitializeRenderTarget()
{
	// Create render target
	RenderTarget = NewObject<UTextureRenderTarget2D>(this);
	RenderTarget->InitAutoFormat(CaptureResolution.X, CaptureResolution.Y);
	RenderTarget->UpdateResourceImmediate(true);
	
	UE_LOG(LogTemp, Log, TEXT("Camera %s initialized render target (%dx%d)"), 
		*CameraID, CaptureResolution.X, CaptureResolution.Y);
}

void AZeroMQCameraActor::SetupSceneCapture()
{
	if (SceneCaptureComponent && RenderTarget)
	{
		SceneCaptureComponent->TextureTarget = RenderTarget;
		
		// Copy camera settings to scene capture
		if (UCameraComponent* CameraComp = GetCameraComponent())
		{
			SceneCaptureComponent->FOVAngle = CameraComp->FieldOfView;
			SceneCaptureComponent->OrthoWidth = CameraComp->OrthoWidth;
			SceneCaptureComponent->ProjectionType = CameraComp->ProjectionMode;
		}
		
		UE_LOG(LogTemp, Log, TEXT("Camera %s scene capture setup complete"), *CameraID);
	}
}

void AZeroMQCameraActor::StartImageCapture()
{
	if (GetWorld() && ImageCaptureInterval > 0.0f)
	{
		GetWorld()->GetTimerManager().SetTimer(
			ImageCaptureTimer,
			this,
			&AZeroMQCameraActor::CaptureAndSendImage,
			ImageCaptureInterval,
			true
		);
		
		UE_LOG(LogTemp, Log, TEXT("Camera %s started image capture (interval: %.2fs)"), *CameraID, ImageCaptureInterval);
	}
}

void AZeroMQCameraActor::StopImageCapture()
{
	if (GetWorld())
	{
		GetWorld()->GetTimerManager().ClearTimer(ImageCaptureTimer);
		UE_LOG(LogTemp, Log, TEXT("Camera %s stopped image capture"), *CameraID);
	}
}
