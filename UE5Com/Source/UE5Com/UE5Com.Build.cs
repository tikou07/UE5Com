// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;

public class UE5Com : ModuleRules
{
	public UE5Com(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "InputCore", "EnhancedInput" });
	}
}
