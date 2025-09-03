#include "ZeroMQReceiverWorker.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonSerializer.h"

// ZeroMQ includes
#ifdef ZMQ_LIBRARY_AVAILABLE
#include "zmq.h"
#else
// Stubs for when ZeroMQ is not available
#define ZMQ_SUB 2
#define ZMQ_SUBSCRIBE 6
#define ZMQ_DONTWAIT 1
static void* zmq_socket(void*, int) { return nullptr; }
static int zmq_close(void*) { return 0; }
static int zmq_connect(void*, const char*) { return -1; }
static int zmq_setsockopt(void*, int, const void*, size_t) { return -1; }
static int zmq_recv(void*, void*, size_t, int) { return -1; }
static const char* zmq_strerror(int) { return "ZeroMQ not available"; }
#endif

FZeroMQReceiverWorker::FZeroMQReceiverWorker(void* InContext, const FString& InServerIP, int32 InPort, TQueue<FCameraTransform, EQueueMode::Mpsc>* InQueue)
	: ZMQContext(InContext)
	, SubscriberSocket(nullptr)
	, ServerIP(InServerIP)
	, Port(InPort)
	, MessageQueue(InQueue)
	, bShouldStop(false)
{
}

FZeroMQReceiverWorker::~FZeroMQReceiverWorker()
{
	Stop();
}

bool FZeroMQReceiverWorker::Init()
{
	if (!ZMQContext)
	{
		return false;
	}

	SubscriberSocket = zmq_socket(ZMQContext, ZMQ_SUB);
	if (!SubscriberSocket)
	{
		return false;
	}

	if (zmq_setsockopt(SubscriberSocket, ZMQ_SUBSCRIBE, "", 0) != 0)
	{
		zmq_close(SubscriberSocket);
		SubscriberSocket = nullptr;
		return false;
	}

	FString Address = FString::Printf(TEXT("tcp://%s:%d"), *ServerIP, Port);
	FTCHARToUTF8 AddressConverter(*Address);
	if (zmq_connect(SubscriberSocket, AddressConverter.Get()) != 0)
	{
		zmq_close(SubscriberSocket);
		SubscriberSocket = nullptr;
		return false;
	}

	return true;
}

uint32 FZeroMQReceiverWorker::Run()
{
	while (!bShouldStop)
	{
		char buffer[1024];
		int size = zmq_recv(SubscriberSocket, buffer, sizeof(buffer) - 1, ZMQ_DONTWAIT);

		if (size > 0)
		{
			buffer[size] = '\0';
			FString JsonString(UTF8_TO_TCHAR(buffer));

			TSharedPtr<FJsonObject> JsonObject;
			TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);

			if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
			{
				FString Type;
				// Accept both "camera_transform" for backward compatibility and "actor_transform" for generic control
				if (JsonObject->TryGetStringField(TEXT("type"), Type) && (Type == TEXT("camera_transform") || Type == TEXT("actor_transform")))
				{
					FCameraTransform Transform;
					// Read "target_id" first, if not present, fall back to "camera_id"
					if (!JsonObject->TryGetStringField(TEXT("target_id"), Transform.CameraID))
					{
						JsonObject->TryGetStringField(TEXT("camera_id"), Transform.CameraID);
					}

					const TSharedPtr<FJsonObject>* LocationObj;
					if (JsonObject->TryGetObjectField(TEXT("location"), LocationObj))
					{
						double X, Y, Z;
						(*LocationObj)->TryGetNumberField(TEXT("x"), X);
						(*LocationObj)->TryGetNumberField(TEXT("y"), Y);
						(*LocationObj)->TryGetNumberField(TEXT("z"), Z);
						Transform.Location = FVector(X, Y, Z);
					}

					const TSharedPtr<FJsonObject>* RotationObj;
					if (JsonObject->TryGetObjectField(TEXT("rotation"), RotationObj))
					{
						double Pitch, Yaw, Roll;
						(*RotationObj)->TryGetNumberField(TEXT("pitch"), Pitch);
						(*RotationObj)->TryGetNumberField(TEXT("yaw"), Yaw);
						(*RotationObj)->TryGetNumberField(TEXT("roll"), Roll);
						Transform.Rotation = FRotator(Pitch, Yaw, Roll);
					}
					MessageQueue->Enqueue(Transform);
				}
			}
		}
		FPlatformProcess::Sleep(0.01f); // 10ms sleep
	}
	return 0;
}

void FZeroMQReceiverWorker::Stop()
{
	bShouldStop = true;
}

void FZeroMQReceiverWorker::Exit()
{
	if (SubscriberSocket)
	{
		zmq_close(SubscriberSocket);
		SubscriberSocket = nullptr;
	}
}

void FZeroMQReceiverWorker::RequestStop()
{
	bShouldStop = true;
}
