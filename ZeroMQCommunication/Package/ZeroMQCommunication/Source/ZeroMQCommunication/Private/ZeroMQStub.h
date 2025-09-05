#pragma once

// Stub definitions when ZeroMQ is not available
#define ZMQ_PUB 1
#define ZMQ_SUB 2
#define ZMQ_SUBSCRIBE 6
#define ZMQ_SNDMORE 2
#define ZMQ_DONTWAIT 1
#define ZMQ_POLLIN 1
#define EAGAIN 11

typedef struct { void* socket; int fd; short events; short revents; } zmq_pollitem_t;

// Stub functions
static void* zmq_ctx_new() { return nullptr; }
static int zmq_ctx_term(void*) { return 0; }
static void* zmq_socket(void*, int) { return nullptr; }
static int zmq_close(void*) { return 0; }
static int zmq_bind(void*, const char*) { return -1; }
static int zmq_connect(void*, const char*) { return -1; }
static int zmq_setsockopt(void*, int, const void*, size_t) { return -1; }
static int zmq_send(void*, const void*, size_t, int) { return -1; }
static int zmq_recv(void*, void*, size_t, int) { return -1; }
static int zmq_poll(zmq_pollitem_t*, int, long) { return 0; }
static int zmq_errno() { return EAGAIN; }
static const char* zmq_strerror(int) { return "ZeroMQ not available"; }
