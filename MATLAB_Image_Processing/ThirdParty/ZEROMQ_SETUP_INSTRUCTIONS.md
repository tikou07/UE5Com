
# ZeroMQ Library Setup Instructions

Generated: 2025-08-08 07:39:33
Target Directory: UE5_Sample\Plugins\ZeroMQCommunication\Source\ZeroMQCommunication\ThirdParty\ZeroMQ
Platform: Windows AMD64

## Automatic Installation Methods

This script attempted the following methods:

1. **vcpkg**: Package manager for C++ libraries
   - Command: vcpkg install zeromq:x64-windows
   - Pros: Easy to use, well-maintained
   - Cons: Requires vcpkg installation

2. **Prebuilt Binaries**: Download from official sources
   - Source: GitHub releases or NuGet packages
   - Pros: No compilation required
   - Cons: May not be available for all platforms

3. **Source Build**: Compile from source code
   - Source: GitHub repository
   - Pros: Always up-to-date, customizable
   - Cons: Requires build tools (CMake, compiler)

## Manual Installation

If automatic methods failed, you can manually install ZeroMQ:

### Windows
1. Install vcpkg:
   ```
   git clone https://github.com/Microsoft/vcpkg.git
   cd vcpkg
   .\bootstrap-vcpkg.bat
   ```

2. Install ZeroMQ:
   ```
   vcpkg install zeromq:x64-windows
   ```

3. Copy libraries to:
   ```
   UE5_Sample\Plugins\ZeroMQCommunication\Source\ZeroMQCommunication\ThirdParty\ZeroMQ\lib\Win64\libzmq-v143-mt-s-4_3_5.lib
   UE5_Sample\Plugins\ZeroMQCommunication\Source\ZeroMQCommunication\ThirdParty\ZeroMQ\bin\Win64\libzmq.dll
   ```

### Linux
1. Install dependencies:
   ```
   sudo apt-get install cmake build-essential
   ```

2. Build from source:
   ```
   git clone https://github.com/zeromq/libzmq.git
   cd libzmq
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release
   make -j4
   sudo make install
   ```

### macOS
1. Install using Homebrew:
   ```
   brew install zeromq
   ```

## Verification

After installation, verify the libraries are in place:
- Check for library files in the target directory
- Run the setup verification script
- Test ZeroMQ functionality

For more information, visit: https://zeromq.org/
