#define S_FUNCTION_NAME sfun_zeromq_image
#define S_FUNCTION_LEVEL 2

#include "simstruc.h"
#include <string>
#include <vector>
#include <memory>
#include "zmq.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

// --- DWork indices ---
enum {
    DWORK_ZMQ_CTX = 0,
    DWORK_ZMQ_SOCKET,
    DWORK_LAST_FRAME,
    DWORK_NUM
};

// --- S-Function parameters ---
#define ADDRESS_PARAM(S) (ssGetSFcnParam(S, 0))
#define CAM_ID_PARAM(S) (ssGetSFcnParam(S, 1))
#define BIND_MODE_PARAM(S) (ssGetSFcnParam(S, 2))
#define TIMEOUT_PARAM(S) (ssGetSFcnParam(S, 3))
#define IMG_H_PARAM(S) (ssGetSFcnParam(S, 4))
#define IMG_W_PARAM(S) (ssGetSFcnParam(S, 5))
#define CHANNELS_PARAM(S) (ssGetSFcnParam(S, 6))
#define SAMPLE_TIME_PARAM(S) (ssGetSFcnParam(S, 7))
#define LOGGING_PARAM(S) (ssGetSFcnParam(S, 8))


static void mdlInitializeSizes(SimStruct *S) {
    ssSetNumSFcnParams(S, 9);
    if (ssGetNumSFcnParams(S) != ssGetSFcnParamsCount(S)) return;

    ssSetNumContStates(S, 0);
    ssSetNumDiscStates(S, 0);

    if (!ssSetNumInputPorts(S, 0)) return;

    if (!ssSetNumOutputPorts(S, 1)) return;
    int_T h = (int_T)mxGetScalar(IMG_H_PARAM(S));
    int_T w = (int_T)mxGetScalar(IMG_W_PARAM(S));
    int_T c = (int_T)mxGetScalar(CHANNELS_PARAM(S));
    ssSetOutputPortWidth(S, 0, h * w * c);
    ssSetOutputPortDataType(S, 0, SS_UINT8);
    ssSetOutputPortComplexSignal(S, 0, COMPLEX_NO);

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
    char cam_id_buf[128];
    mxGetString(CAM_ID_PARAM(S), cam_id_buf, 128);
    int_T timeout_ms = (int_T)mxGetScalar(TIMEOUT_PARAM(S));
    bool bind_mode = *mxGetLogicals(BIND_MODE_PARAM(S));
    bool enable_logging = *mxGetLogicals(LOGGING_PARAM(S));

    void* context = zmq_ctx_new();
    if (!context) {
        ssSetErrorStatus(S, "Failed to create ZeroMQ context.");
        return;
    }

    void* socket = zmq_socket(context, ZMQ_SUB);
    if (!socket) {
        zmq_ctx_term(context);
        ssSetErrorStatus(S, "Failed to create ZeroMQ SUB socket.");
        return;
    }

    zmq_setsockopt(socket, ZMQ_SUBSCRIBE, cam_id_buf, strlen(cam_id_buf));
    zmq_setsockopt(socket, ZMQ_RCVTIMEO, &timeout_ms, sizeof(timeout_ms));

    if (bind_mode) {
        if (zmq_bind(socket, address_buf) != 0) {
            ssPrintf("Error binding socket: %s\n", zmq_strerror(zmq_errno()));
            zmq_close(socket);
            zmq_ctx_term(context);
            ssSetErrorStatus(S, "Failed to bind ZeroMQ SUB socket.");
            return;
        }
    } else {
        if (zmq_connect(socket, address_buf) != 0) {
            ssPrintf("Error connecting socket: %s\n", zmq_strerror(zmq_errno()));
            zmq_close(socket);
            zmq_ctx_term(context);
            ssSetErrorStatus(S, "Failed to connect ZeroMQ SUB socket.");
            return;
        }
    }

    ssGetPWork(S)[DWORK_ZMQ_CTX] = context;
    ssGetPWork(S)[DWORK_ZMQ_SOCKET] = socket;

    // Allocate memory for the last frame
    int_T out_width = ssGetOutputPortWidth(S, 0);
    uint8_T* last_frame = (uint8_T*)calloc(out_width, sizeof(uint8_T));
    ssGetPWork(S)[DWORK_LAST_FRAME] = last_frame;

    if (enable_logging) {
        ssPrintf("[sfun_zeromq_image] Started. Connected to %s, Subscribing to '%s'\n", address_buf, cam_id_buf);
    }
}

static void mdlOutputs(SimStruct *S, int_T tid) {
    void* socket = ssGetPWork(S)[DWORK_ZMQ_SOCKET];
    uint8_T* last_frame = (uint8_T*)ssGetPWork(S)[DWORK_LAST_FRAME];
    uint8_T* y = (uint8_T*)ssGetOutputPortSignal(S, 0);
    int_T out_width = ssGetOutputPortWidth(S, 0);
    bool enable_logging = *mxGetLogicals(LOGGING_PARAM(S));

    if (!socket || !last_frame) {
        memcpy(y, last_frame, out_width * sizeof(uint8_T));
        return;
    }

    // Receive multipart message
    zmq_msg_t topic_msg;
    zmq_msg_init(&topic_msg);
    int recv_size = zmq_msg_recv(&topic_msg, socket, 0);

    if (recv_size != -1) {
        zmq_msg_t data_msg;
        zmq_msg_init(&data_msg);
        recv_size = zmq_msg_recv(&data_msg, socket, 0);
        
        if (recv_size != -1) {
            // Decode image from memory using stb_image
            int x, y_img, n;
            int desired_channels = (int)mxGetScalar(CHANNELS_PARAM(S));
            unsigned char *decoded_data = stbi_load_from_memory((const stbi_uc*)zmq_msg_data(&data_msg), recv_size, &x, &y_img, &n, desired_channels);

            if (decoded_data) {
                size_t decoded_size = x * y_img * desired_channels;
                if (decoded_size == out_width) {
                    if (enable_logging) {
                        char* topic_str = (char*)zmq_msg_data(&topic_msg);
                        size_t topic_size = zmq_msg_size(&topic_msg);
                        ssPrintf("[sfun_zeromq_image] T=%.4f, Received image from topic '%.*s' (%dx%dx%d, %d bytes)\n",
                                 ssGetT(S), (int)topic_size, topic_str, x, y_img, desired_channels, recv_size);
                    }
                    memcpy(y, decoded_data, decoded_size * sizeof(uint8_T));
                    memcpy(last_frame, decoded_data, decoded_size * sizeof(uint8_T));
                } else {
                    if (enable_logging) {
                        ssPrintf("[sfun_zeromq_image] Warning: Decoded image size (%dx%dx%d=%d) does not match output port width (%d).\n", x, y_img, desired_channels, decoded_size, out_width);
                    }
                    memcpy(y, last_frame, out_width * sizeof(uint8_T));
                }
                stbi_image_free(decoded_data);
            } else {
                if (enable_logging) {
                    ssPrintf("[sfun_zeromq_image] stbi_load_from_memory failed: %s\n", stbi_failure_reason());
                }
                memcpy(y, last_frame, out_width * sizeof(uint8_T));
            }
        } else {
            memcpy(y, last_frame, out_width * sizeof(uint8_T));
        }
        zmq_msg_close(&data_msg);
    } else {
        memcpy(y, last_frame, out_width * sizeof(uint8_T));
    }
    zmq_msg_close(&topic_msg);
}

static void mdlTerminate(SimStruct *S) {
    void* socket = ssGetPWork(S)[DWORK_ZMQ_SOCKET];
    void* context = ssGetPWork(S)[DWORK_ZMQ_CTX];
    uint8_T* last_frame = (uint8_T*)ssGetPWork(S)[DWORK_LAST_FRAME];
    bool enable_logging = *mxGetLogicals(LOGGING_PARAM(S));

    if (socket) {
        zmq_close(socket);
    }
    if (context) {
        zmq_ctx_term(context);
    }
    if (last_frame) {
        free(last_frame);
    }

    if (enable_logging) {
        ssPrintf("[sfun_zeromq_image] Terminated.\n");
    }
}

#ifdef MATLAB_MEX_FILE
#include "simulink.c"
#else
#include "cg_sfun.h"
#endif
