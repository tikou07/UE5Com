// Copyright Epic Games, Inc. All Rights Reserved.

#include "UE5ComGameMode.h"
#include "UE5ComCharacter.h"
#include "UObject/ConstructorHelpers.h"

AUE5ComGameMode::AUE5ComGameMode()
{
	// set default pawn class to our Blueprinted character
	static ConstructorHelpers::FClassFinder<APawn> PlayerPawnBPClass(TEXT("/Game/ThirdPerson/Blueprints/BP_ThirdPersonCharacter"));
	if (PlayerPawnBPClass.Class != NULL)
	{
		DefaultPawnClass = PlayerPawnBPClass.Class;
	}
}
