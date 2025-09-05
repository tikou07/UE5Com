#include "ZeroMQCommunication.h"

#define LOCTEXT_NAMESPACE "FZeroMQCommunicationModule"

void FZeroMQCommunicationModule::StartupModule()
{
	// This code will execute after your module is loaded into memory; the exact timing is specified in the .uplugin file per-module
	UE_LOG(LogTemp, Warning, TEXT("ZeroMQ Communication Plugin Started"));
}

void FZeroMQCommunicationModule::ShutdownModule()
{
	// This function may be called during shutdown to clean up your module.  For modules that support dynamic reloading,
	// we call this function before unloading the module.
	UE_LOG(LogTemp, Warning, TEXT("ZeroMQ Communication Plugin Shutdown"));
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FZeroMQCommunicationModule, ZeroMQCommunication)
