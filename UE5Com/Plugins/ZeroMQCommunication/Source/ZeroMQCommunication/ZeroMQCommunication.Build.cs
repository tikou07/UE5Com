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
			
			// Only add library if it exists and is valid
			if (File.Exists(ZmqLibFile))
			{
				FileInfo libInfo = new FileInfo(ZmqLibFile);
				if (libInfo.Length > 1000) // Basic check for non-empty file
				{
					PublicAdditionalLibraries.Add(ZmqLibFile);
					PublicDefinitions.Add("ZMQ_LIBRARY_AVAILABLE=1");
					
					// Copy DLL to output directory
					string DllPath = Path.Combine(ZeroMQPath, "bin", "Win64", "libzmq-mt-4_3_5.dll");
					if (File.Exists(DllPath))
					{
						RuntimeDependencies.Add(DllPath);
					}
					
					System.Console.WriteLine("ZeroMQ library found and enabled: " + libInfo.Length + " bytes");
				}
				else
				{
					System.Console.WriteLine("Warning: ZeroMQ library file appears to be corrupted or empty");
				}
			}
			else
			{
				System.Console.WriteLine("Warning: ZeroMQ library file not found - building without ZeroMQ support");
			}
			
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
			PublicAdditionalLibraries.Add(Path.Combine(LibPath, "libzmq.a"));
			
			// Add Linux system libraries
			PublicSystemLibraries.AddRange(new string[] {
				"pthread",
				"rt"
			});
		}
		else if (Target.Platform == UnrealTargetPlatform.Mac)
		{
			// Mac-specific settings
			PublicDefinitions.Add("PLATFORM_MAC=1");
			
			string LibPath = Path.Combine(ZeroMQPath, "lib", "Mac");
			PublicAdditionalLibraries.Add(Path.Combine(LibPath, "libzmq.a"));
		}
	}
}
