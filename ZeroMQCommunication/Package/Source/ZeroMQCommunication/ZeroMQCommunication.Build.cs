using UnrealBuildTool;
using System.IO;

public class ZeroMQCommunication : ModuleRules
{
	public ZeroMQCommunication(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;
		bEnableExceptions = true;

		PublicIncludePaths.AddRange(
			new string[] {
				Path.Combine(ModuleDirectory, "ThirdParty", "ZeroMQ", "include")
			}
		);

		PrivateIncludePaths.AddRange(
			new string[] {
			}
		);

		PublicDependencyModuleNames.AddRange(
			new string[]
			{
				"Core",
				"CoreUObject",
				"Engine",
				"RenderCore",
				"RHI",
				"CinematicCamera",
				"ImageWrapper",
				"ImageWriteQueue",
				"Json",
				"HTTP"
			}
		);

		PrivateDependencyModuleNames.AddRange(
			new string[]
			{
				"Slate",
				"SlateCore"
			}
		);

		// Editor-only dependencies: only include these when building editor targets.
		if (Target.bBuildEditor)
		{
			PrivateDependencyModuleNames.AddRange(
				new string[]
				{
					"EditorStyle",
					"EditorWidgets",
					"UnrealEd",
					"ToolMenus",
					"Projects"
				}
			);
		}

		DynamicallyLoadedModuleNames.AddRange(
			new string[]
			{
			}
		);

		// ZeroMQ library integration
		string ZeroMQPath = Path.Combine(ModuleDirectory, "ThirdParty", "ZeroMQ");
		
		if (Target.Platform == UnrealTargetPlatform.Win64)
		{
			// Windows-specific settings
			PublicDefinitions.Add("PLATFORM_WINDOWS=1");
			PublicDefinitions.Add("ZMQ_STATIC=1");
			
			string LibPath = Path.Combine(ZeroMQPath, "lib", "Win64");
			string ZmqLibFile = Path.Combine(LibPath, "libzmq-v143-mt-s-4_3_5.lib");
			
			// Check if the static library exists and is valid
			if (!File.Exists(ZmqLibFile))
			{
				throw new BuildException($"ZeroMQ static library not found at {ZmqLibFile}. Please ensure all required libraries are included in the ThirdParty directory.");
			}
			if (new FileInfo(ZmqLibFile).Length < 1000)
			{
				throw new BuildException($"ZeroMQ static library appears to be corrupted or empty at {ZmqLibFile}.");
			}
			
			PublicAdditionalLibraries.Add(ZmqLibFile);
			PublicDefinitions.Add("ZMQ_LIBRARY_AVAILABLE=1");
			
			// Check for the DLL and add it to runtime dependencies
			string DllPath = Path.Combine(ZeroMQPath, "bin", "Win64", "libzmq-mt-4_3_5.dll");
			if (!File.Exists(DllPath))
			{
				throw new BuildException($"ZeroMQ DLL not found at {DllPath}.");
			}
			RuntimeDependencies.Add(DllPath, StagedFileType.NonUFS);
			
			System.Console.WriteLine("ZeroMQ Windows libraries found and enabled.");
			
			// Add Windows socket libraries
			PublicSystemLibraries.AddRange(new string[] {
				"ws2_32.lib",
				"iphlpapi.lib"
			});
		}
		else if (Target.Platform == UnrealTargetPlatform.Linux)
		{
			// Linux-specific settings
			PublicDefinitions.Add("PLATFORM_LINUX=1");
			string LibPath = Path.Combine(ZeroMQPath, "lib", "Linux");
			string ZmqLibFile = Path.Combine(LibPath, "libzmq.a");

			if (!File.Exists(ZmqLibFile))
			{
				throw new BuildException($"ZeroMQ Linux library not found at {ZmqLibFile}. Please compile and place the required .a file in this location.");
			}
			PublicAdditionalLibraries.Add(ZmqLibFile);
		}
		else if (Target.Platform == UnrealTargetPlatform.Mac)
		{
			// Mac-specific settings
			PublicDefinitions.Add("PLATFORM_MAC=1");
			string LibPath = Path.Combine(ZeroMQPath, "lib", "Mac");
			string ZmqLibFile = Path.Combine(LibPath, "libzmq.a");
			
			if (!File.Exists(ZmqLibFile))
			{
				throw new BuildException($"ZeroMQ Mac library not found at {ZmqLibFile}. Please compile and place the required .a file in this location.");
			}
			PublicAdditionalLibraries.Add(ZmqLibFile);
		}
		else
        {
            // Unsupported platform
            throw new BuildException($"ZeroMQ plugin does not currently support the target platform: {Target.Platform}");
        }
	}
}
