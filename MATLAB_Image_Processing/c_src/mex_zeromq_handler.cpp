#include "mex.h"
#include <string>
#include <vector>
#include <memory>
#include "zmq.h"
#include "json.hpp"

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

using json = nlohmann::json;

// --- Global state ---
struct ZMQState {
    void* context = nullptr;
    void* image_socket = nullptr;
    void* control_socket = nullptr;
    std::vector<uint8_t> last_frame_buffer;
    bool image_initialized = false;
    bool control_initialized = false;
};

static ZMQState state;

// --- Cleanup function ---
void cleanup() {
    if (state.image_socket) {
        zmq_close(state.image_socket);
        state.image_socket = nullptr;
    }
    if (state.control_socket) {
        zmq_close(state.control_socket);
        state.control_socket = nullptr;
    }
    if (state.context) {
        zmq_ctx_term(state.context);
        state.context = nullptr;
    }
    state.image_initialized = false;
    state.control_initialized = false;
    mexPrintf("ZeroMQ Handler cleaned up.\n");
}

// --- MEX Gateway function ---
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs < 1) mexErrMsgIdAndTxt("ZMQ:Handler:nrhs", "Command required.");
    char* command = mxArrayToString(prhs[0]);

    // --- Context Management ---
    if (state.context == nullptr) {
        state.context = zmq_ctx_new();
        if (!state.context) mexErrMsgIdAndTxt("ZMQ:Handler:zmq_error", "Failed to create ZMQ context.");
        mexAtExit(cleanup);
    }

    // --- Command Dispatcher ---
    if (strcmp(command, "image_init") == 0) {
        if (state.image_initialized) { mexPrintf("Image receiver already initialized.\n"); return; }
        if (nrhs != 8) mexErrMsgIdAndTxt("ZMQ:Handler:nrhs", "image_init requires 7 args.");
        
        char address[256], topic[128];
        mxGetString(prhs[1], address, sizeof(address));
        mxGetString(prhs[2], topic, sizeof(topic));
        bool bind_mode = mxGetScalar(prhs[3]);
        int timeout = (int)mxGetScalar(prhs[4]);
        int h = (int)mxGetScalar(prhs[5]);
        int w = (int)mxGetScalar(prhs[6]);
        int c = (int)mxGetScalar(prhs[7]);

        state.image_socket = zmq_socket(state.context, ZMQ_SUB);
        zmq_setsockopt(state.image_socket, ZMQ_SUBSCRIBE, topic, strlen(topic));
        zmq_setsockopt(state.image_socket, ZMQ_RCVTIMEO, &timeout, sizeof(timeout));
        if (bind_mode ? zmq_bind(state.image_socket, address) != 0 : zmq_connect(state.image_socket, address) != 0) {
            mexErrMsgIdAndTxt("ZMQ:Handler:zmq_error", "Image socket connection failed.");
        }
        state.last_frame_buffer.assign(h * w * c, 0);
        state.image_initialized = true;

    } else if (strcmp(command, "image_receive") == 0) {
        if (!state.image_initialized) mexErrMsgIdAndTxt("ZMQ:Handler:not_init", "Image receiver not initialized.");
        
        zmq_msg_t topic_msg, data_msg;
        zmq_msg_init(&topic_msg);
        if (zmq_msg_recv(&topic_msg, state.image_socket, 0) != -1) {
            zmq_msg_init(&data_msg);
            if (zmq_msg_recv(&data_msg, state.image_socket, 0) != -1) {
                int x, y, n;
                unsigned char* decoded = stbi_load_from_memory((const stbi_uc*)zmq_msg_data(&data_msg), zmq_msg_size(&data_msg), &x, &y, &n, 0);
                if (decoded) {
                    if (x * y * n == state.last_frame_buffer.size()) {
                        memcpy(state.last_frame_buffer.data(), decoded, state.last_frame_buffer.size());
                    }
                    stbi_image_free(decoded);
                }
            }
            zmq_msg_close(&data_msg);
        }
        zmq_msg_close(&topic_msg);
        
        plhs[0] = mxCreateNumericMatrix(1, state.last_frame_buffer.size(), mxUINT8_CLASS, mxREAL);
        memcpy(mxGetData(plhs[0]), state.last_frame_buffer.data(), state.last_frame_buffer.size());

    } else if (strcmp(command, "control_init") == 0) {
        if (state.control_initialized) { mexPrintf("Control sender already initialized.\n"); return; }
        if (nrhs != 2) mexErrMsgIdAndTxt("ZMQ:Handler:nrhs", "control_init requires 1 arg.");

        char address[256];
        mxGetString(prhs[1], address, sizeof(address));
        state.control_socket = zmq_socket(state.context, ZMQ_PUB);
        if (zmq_bind(state.control_socket, address) != 0) {
            mexErrMsgIdAndTxt("ZMQ:Handler:zmq_error", "Control socket bind failed.");
        }
        #ifdef _WIN32
            Sleep(100);
        #else
            usleep(100 * 1000);
        #endif
        state.control_initialized = true;

    } else if (strcmp(command, "control_send") == 0) {
        if (!state.control_initialized) mexErrMsgIdAndTxt("ZMQ:Handler:not_init", "Control sender not initialized.");
        if (nrhs != 8) mexErrMsgIdAndTxt("ZMQ:Handler:nrhs", "control_send requires 7 args.");

        char target_id[128];
        mxGetString(prhs[1], target_id, sizeof(target_id));
        json msg;
        msg["type"] = "actor_transform";
        msg["target_id"] = std::string(target_id);
        msg["location"]["x"] = mxGetScalar(prhs[2]);
        msg["location"]["y"] = mxGetScalar(prhs[3]);
        msg["location"]["z"] = mxGetScalar(prhs[4]);
        msg["rotation"]["roll"] = mxGetScalar(prhs[5]);
        msg["rotation"]["pitch"] = mxGetScalar(prhs[6]);
        msg["rotation"]["yaw"] = mxGetScalar(prhs[7]);
        
        std::string s = msg.dump();
        zmq_msg_t z_msg;
        zmq_msg_init_size(&z_msg, s.length());
        memcpy(zmq_msg_data(&z_msg), s.c_str(), s.length());
        zmq_msg_send(&z_msg, state.control_socket, 0);
        zmq_msg_close(&z_msg);

    } else if (strcmp(command, "terminate") == 0) {
        cleanup();
    } else {
        mexErrMsgIdAndTxt("ZMQ:Handler:invalid_command", "Invalid command.");
    }

    mxFree(command);
}
