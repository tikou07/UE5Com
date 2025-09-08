function build_mex_files()
% build_mex_files - Compiles the ZMQ handler MEX file from source.
% This script uses CMake to build the ZeroMQ library from the included
% submodule, ensuring compatibility with the MATLAB-selected C++ compiler.

% --- Clear any loaded MEX files ---
clear mex;

% --- Configuration ---
PROJECT_ROOT = fileparts(mfilename('fullpath'));
ZMQ_SOURCE_DIR = fullfile(PROJECT_ROOT, 'ThirdParty', 'zeromq');
CMAKE_INSTALL_DIR = fullfile(PROJECT_ROOT, 'ThirdParty', 'cmake');
ZMQ_BUILD_DIR = fullfile(ZMQ_SOURCE_DIR, 'build');
ZMQ_INSTALL_DIR = fullfile(ZMQ_BUILD_DIR, 'install'); % Install into a subdir of the build dir

% --- Build Command ---
fprintf('Building MEX file for c_src/mex_zeromq_handler.cpp...\n');

% 1. Find CMake executable
cmake_exe = find_cmake(CMAKE_INSTALL_DIR);
if isempty(cmake_exe)
    error('CMake not found. Please run build.ps1 from an Administrator PowerShell prompt to ensure all dependencies are set up correctly.');
end

% 2. Build ZeroMQ library using CMake
fprintf('--- Building ZeroMQ library from source ---\n');
% Clean up previous build artifacts to avoid configuration conflicts
if exist(ZMQ_BUILD_DIR, 'dir')
    fprintf('Cleaning previous build directory...\n');
    rmdir(ZMQ_BUILD_DIR, 's');
end
mkdir(ZMQ_BUILD_DIR);

% Get MATLAB's C++ compiler configuration
compiler_cfg = mex.getCompilerConfigurations('C++', 'Selected');
if isempty(compiler_cfg)
    error('No C++ compiler is selected in MATLAB. Please run "mex -setup C++".');
end

% Configure CMake command
cmake_configure_cmd = sprintf('"%s" -S "%s" -B "%s" -A x64 -DCMAKE_INSTALL_PREFIX="%s" -DBUILD_STATIC=ON -DBUILD_TESTS=OFF -DWITH_LIBSODIUM=OFF', ...
    cmake_exe, ZMQ_SOURCE_DIR, ZMQ_BUILD_DIR, ZMQ_INSTALL_DIR);

% Build command
cmake_build_cmd = sprintf('"%s" --build "%s" --config Release --target install', cmake_exe, ZMQ_BUILD_DIR);

% Execute CMake commands
fprintf('Configuring ZeroMQ build...\n');
[status, cmdout] = system(cmake_configure_cmd);
if status ~= 0
    disp(cmdout);
    error('CMake configuration failed.');
end

fprintf('Building and installing ZeroMQ...\n');
[status, cmdout] = system(cmake_build_cmd);
if status ~= 0
    disp(cmdout);
    error('ZeroMQ build failed.');
end
fprintf('--- ZeroMQ library built successfully ---\n');


% 3. Build the MEX file
fprintf('--- Building MEX file ---\n');
SRC_FILE = fullfile(PROJECT_ROOT, 'c_src', 'mex_zeromq_handler.cpp');
OUTPUT_NAME = 'mex_zeromq_handler';

% Create output directory if it doesn't exist
if ~exist(fullfile(PROJECT_ROOT, 'mex'), 'dir')
    mkdir(fullfile(PROJECT_ROOT, 'mex'));
end
output_file = fullfile(PROJECT_ROOT, 'mex', [OUTPUT_NAME, '.', mexext]);

% Delete existing MEX file
if exist(output_file, 'file')
    fprintf('Attempting to delete existing file: %s\n', output_file);
    max_retries = 5;
    for i = 1:max_retries
        try
            delete(output_file);
            pause(0.2); % Short pause to allow filesystem to catch up
        catch ME
            fprintf('Warning: Attempt %d to delete file failed: %s\n', i, ME.message);
        end
        
        if ~exist(output_file, 'file')
            fprintf('Successfully deleted existing file.\n');
            break;
        end
        
        if i < max_retries
            fprintf('File still exists. Retrying in 1 second...\n');
            pause(1);
        else
            error('Could not delete existing MEX file: %s. It may be locked by another process (e.g., another MATLAB instance or a zombie process). Please close any other MATLAB instances and try again.', output_file);
        end
    end
end

% Construct the mex command
ZMQ_INC_DIR_BUILT = fullfile(ZMQ_INSTALL_DIR, 'include');
ZMQ_LIB_DIR_BUILT = fullfile(ZMQ_INSTALL_DIR, 'lib');
MEX_COMMON_INC_DIR = fullfile(PROJECT_ROOT, 'ThirdParty', 'include');

% Find the built library file (name can vary slightly)
lib_file = dir(fullfile(ZMQ_LIB_DIR_BUILT, '*zmq*.lib'));
if isempty(lib_file)
    lib_file = dir(fullfile(ZMQ_LIB_DIR_BUILT, '*zmq*.a'));
end
if isempty(lib_file)
    error('Could not find built ZeroMQ library file.');
end
[~, lib_name, ~] = fileparts(lib_file(1).name);

mex_command = { ...
    '-v', ...
    ['-I"' ZMQ_INC_DIR_BUILT '"'], ...
    ['-I"' MEX_COMMON_INC_DIR '"'], ...
    ['-L"' ZMQ_LIB_DIR_BUILT '"'], ...
    ['-l' lib_name], ...
    'COMPFLAGS="$COMPFLAGS /MT"', ... % For MSVC static linking
    'LDFLAGS="$LDFLAGS -static"', ... % For MinGW static linking
    ['"' SRC_FILE '"'], ...
    '-output', ['"' output_file '"'] ...
};

% Execute the mex command
try
    mex(mex_command{:});
    fprintf('Successfully built %s.\n', output_file);
catch ME
    fprintf('Error building %s:\n', SRC_FILE);
    rethrow(ME);
end

fprintf('All MEX files built successfully.\n');

% 4. Copy ZeroMQ DLL to the mex directory
fprintf('--- Copying ZeroMQ DLL to mex directory ---\n');
ZMQ_DLL_DIR = fullfile(ZMQ_BUILD_DIR, 'bin', 'Release');
dll_file = dir(fullfile(ZMQ_DLL_DIR, '*zmq*.dll'));
if isempty(dll_file)
    warning('Could not find built ZeroMQ DLL file. Runtime errors may occur.');
else
    source_dll = fullfile(dll_file(1).folder, dll_file(1).name);
    destination_dll = fullfile(PROJECT_ROOT, 'mex', dll_file(1).name);
    copyfile(source_dll, destination_dll);
    fprintf('Successfully copied %s to mex directory.\n', dll_file(1).name);
end

end

function cmake_path = find_cmake(local_cmake_dir)
    % Check for CMake in the local ThirdParty directory first, then system PATH
    local_cmake_exe = fullfile(local_cmake_dir, 'bin', 'cmake.exe');
    if exist(local_cmake_exe, 'file')
        cmake_path = local_cmake_exe;
        return;
    end
    
    [status, result] = system('where cmake');
    if status == 0
        lines = strsplit(strtrim(result), '\n');
        cmake_path = lines{1};
    else
        cmake_path = '';
    end
end
