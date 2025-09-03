
# ZeroMQ Library Setup Instructions

This is a placeholder for the actual ZeroMQ library files.
To complete the setup, please:

1. Download ZeroMQ 4.3.5 for Windows x64 from:
   https://github.com/zeromq/libzmq/releases/

2. Extract the following files to this directory:
   - libzmq-v143-mt-s-4_3_5.lib (static library)
   - libzmq.dll (dynamic library)

3. Or use vcpkg:
   vcpkg install zeromq:x64-windows

4. Or build from source:
   git clone https://github.com/zeromq/libzmq.git
   cd libzmq
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_STATIC=ON
   cmake --build . --config Release

Generated on: 2025-08-08 07:26:57
Setup script: D:\takashi\workspace\UE5PyCom\setup_ue5_zeromq_complete.py
