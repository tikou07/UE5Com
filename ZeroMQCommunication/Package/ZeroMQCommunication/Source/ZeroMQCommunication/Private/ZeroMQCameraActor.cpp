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
	SceneCaptureComponent->bAlwaysPersistRenderingState = true;

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
	
	// Sync SceneCaptureComponent settings with CameraComponent during play mode
	// This is necessary because Cesium3DTileset and other dynamic elements
	// may change their rendering behavior when transitioning from editor to play mode
	if (GetWorld() && GetWorld()->IsGameWorld() && SceneCaptureComponent && GetCameraComponent())
	{
		UCameraComponent* CameraComp = GetCameraComponent();
		
		// Sync basic camera settings that may change during play mode
		SceneCaptureComponent->FOVAngle = CameraComp->FieldOfView;
		SceneCaptureComponent->OrthoWidth = CameraComp->OrthoWidth;
		SceneCaptureComponent->ProjectionType = CameraComp->ProjectionMode;
		
		// Ensure unlimited view distance for Cesium3DTileset compatibility
		// CameraComponent doesn't have MaxDrawDistance property in UE5
		SceneCaptureComponent->MaxViewDistanceOverride = -1; // Unlimited
	}
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

	// Transform and settings are already synchronized in Tick function
	// No need for additional synchronization here
	
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

		// Use LDR capture source to match viewport and ensure Cesium3DTileset compatibility
		SceneCaptureComponent->CaptureSource = SCS_FinalColorLDR;
		
		// Cesium3DTileset specific settings to prevent tile culling issues
		SceneCaptureComponent->bUseRayTracingIfEnabled = false;
		SceneCaptureComponent->LODDistanceFactor = 1.0f;
		SceneCaptureComponent->MaxViewDistanceOverride = -1; // Unlimited view distance
		
		// Copy camera settings to scene capture
		if (UCameraComponent* CameraComp = GetCameraComponent())
		{
			SceneCaptureComponent->FOVAngle = CameraComp->FieldOfView;
			SceneCaptureComponent->OrthoWidth = CameraComp->OrthoWidth;
			SceneCaptureComponent->ProjectionType = CameraComp->ProjectionMode;

			// Copy post-process settings from camera component
			// This ensures visual consistency with the viewport
			SceneCaptureComponent->PostProcessSettings = CameraComp->PostProcessSettings;
		}
		
		UE_LOG(LogTemp, Log, TEXT("Camera %s scene capture setup complete with Cesium3DTileset compatibility"), *CameraID);
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
