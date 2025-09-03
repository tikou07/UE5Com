#define S_FUNCTION_NAME sfun_zeromq_control
#define S_FUNCTION_LEVEL 2

#include "simstruc.h"
#include <string>
#include <vector>
#include <memory>
#include "zmq.h"
#include "json.hpp"

#ifdef _WIN32
#include <windows.h> // For Sleep()
#else
#include <unistd.h> // For usleep()
#endif

// Use nlohmann::json for convenience
using json = nlohmann::json;

// --- DWork indices ---
enum {
    DWORK_ZMQ_CTX = 0,
    DWORK_ZMQ_SOCKET,
    DWORK_NUM
};

// --- S-Function parameters ---
#define ADDRESS_PARAM(S) (ssGetSFcnParam(S, 0))
#define TARGET_ID_PARAM(S) (ssGetSFcnParam(S, 1))
#define SAMPLE_TIME_PARAM(S) (ssGetSFcnParam(S, 2))
#define LOGGING_PARAM(S) (ssGetSFcnParam(S, 3))

static void mdlInitializeSizes(SimStruct *S) {
    ssSetNumSFcnParams(S, 4);
    if (ssGetNumSFcnParams(S) != ssGetSFcnParamsCount(S)) return;

    ssSetNumContStates(S, 0);
    ssSetNumDiscStates(S, 0);

    if (!ssSetNumInputPorts(S, 6)) return;
    for (int i = 0; i < 6; ++i) {
        ssSetInputPortWidth(S, i, 1);
        ssSetInputPortDataType(S, i, SS_DOUBLE);
        ssSetInputPortRequiredContiguous(S, i, true);
        ssSetInputPortDirectFeedThrough(S, i, 1);
    }

    if (!ssSetNumOutputPorts(S, 0)) return;

    ssSetNumSampleTimes(S, 1);
    ssSetNumRWork(S, 0);
    ssSetNumIWork(S, 0);
    ssSetNumPWork(S, DWORK_NUM);
    ssSetNumModes(S, 0);
    ssSetNumNonsampledZCs(S, 0);

    ssSetOptions(S, 0);
}

static void mdlInitializeSampleTimes(SimStruct *S) {
    double sampleTime = mxGetScalar(SAMPLE_TIME_PARAM(S));
    if (sampleTime < 0.0) {
        ssSetSampleTime(S, 0, INHERITED_SAMPLE_TIME);
    } else {
        ssSetSampleTime(S, 0, sampleTime);
    }
    ssSetOffsetTime(S, 0, 0.0);
}

#define MDL_START
static void mdlStart(SimStruct *S) {
    char address_buf[256];
    mxGetString(ADDRESS_PARAM(S), address_buf, 256);
    bool enable_logging = *mxGetLogicals(LOGGING_PARAM(S));

    void* context = zmq_ctx_new();
    if (!context) {
        ssSetErrorStatus(S, "Failed to create ZeroMQ context.");
        return;
    }

    void* socket = zmq_socket(context, ZMQ_PUB);
    if (!socket) {
        zmq_ctx_term(context);
        ssSetErrorStatus(S, "Failed to create ZeroMQ PUB socket.");
        return;
    }

    // Set a high-water mark for the outbound message queue
    int sndhwm = 1000;
    zmq_setsockopt(socket, ZMQ_SNDHWM, &sndhwm, sizeof(sndhwm));

    // Set a linger period for the socket
    int linger = 0; // Discard pending messages immediately on close
    zmq_setsockopt(socket, ZMQ_LINGER, &linger, sizeof(linger));

    if (zmq_bind(socket, address_buf) != 0) {
        ssPrintf("Error binding socket: %s\n", zmq_strerror(zmq_errno()));
        zmq_close(socket);
        zmq_ctx_term(context);
        ssSetErrorStatus(S, "Failed to bind ZeroMQ PUB socket.");
        return;
    }

    // Add a small delay to allow subscribers to connect
    #ifdef _WIN32
        Sleep(100); // 100 ms delay on Windows
    #else
        usleep(100 * 1000); // 100 ms delay on Unix-like systems
    #endif

    ssGetPWork(S)[DWORK_ZMQ_CTX] = context;
    ssGetPWork(S)[DWORK_ZMQ_SOCKET] = socket;

    if (enable_logging) {
        ssPrintf("[sfun_zeromq_control] Started and bound to %s\n", address_buf);
    }
}

static void mdlOutputs(SimStruct *S, int_T tid) {
    void* socket = ssGetPWork(S)[DWORK_ZMQ_SOCKET];
    if (!socket) return;

    // Get inputs
    const real_T* x = ssGetInputPortRealSignal(S, 0);
    const real_T* y = ssGetInputPortRealSignal(S, 1);
    const real_T* z = ssGetInputPortRealSignal(S, 2);
    const real_T* roll = ssGetInputPortRealSignal(S, 3);
    const real_T* pitch = ssGetInputPortRealSignal(S, 4);
    const real_T* yaw = ssGetInputPortRealSignal(S, 5);

    char target_id_buf[128];
    mxGetString(TARGET_ID_PARAM(S), target_id_buf, 128);

    // Create JSON message
    json msg;
    msg["type"] = "actor_transform";
    msg["target_id"] = std::string(target_id_buf);
    msg["location"]["x"] = *x;
    msg["location"]["y"] = *y;
    msg["location"]["z"] = *z;
    msg["rotation"]["roll"] = *roll;
    msg["rotation"]["pitch"] = *pitch;
    msg["rotation"]["yaw"] = *yaw;

    std::string json_str = msg.dump();

    // Send message
    bool enable_logging = *mxGetLogicals(LOGGING_PARAM(S));
    if (enable_logging) {
        ssPrintf("[sfun_zeromq_control] T=%.4f, Sending: %s\n", ssGetT(S), json_str.c_str());
    }

    zmq_msg_t zmq_msg;
    zmq_msg_init_size(&zmq_msg, json_str.length());
    memcpy(zmq_msg_data(&zmq_msg), json_str.c_str(), json_str.length());
    zmq_msg_send(&zmq_msg, socket, 0);
    zmq_msg_close(&zmq_msg);
}

static void mdlTerminate(SimStruct *S) {
    void* socket = ssGetPWork(S)[DWORK_ZMQ_SOCKET];
    void* context = ssGetPWork(S)[DWORK_ZMQ_CTX];
    bool enable_logging = *mxGetLogicals(LOGGING_PARAM(S));

    if (socket) {
        zmq_close(socket);
        ssGetPWork(S)[DWORK_ZMQ_SOCKET] = nullptr;
    }
    if (context) {
        zmq_ctx_term(context);
        ssGetPWork(S)[DWORK_ZMQ_CTX] = nullptr;
    }

    if (enable_logging) {
        ssPrintf("[sfun_zeromq_control] Terminated.\n");
    }
}

#ifdef MATLAB_MEX_FILE
#include "simulink.c"
#else
#include "cg_sfun.h"
#endif
