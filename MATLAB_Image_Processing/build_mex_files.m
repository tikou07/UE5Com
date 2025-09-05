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
if ~exist(ZMQ_BUILD_DIR, 'dir')
    mkdir(ZMQ_BUILD_DIR);
end

% Get MATLAB's C++ compiler configuration
compiler_cfg = mex.getCompilerConfigurations('C++', 'Selected');
if isempty(compiler_cfg)
    error('No C++ compiler is selected in MATLAB. Please run "mex -setup C++".');
end

% Configure CMake command
cmake_configure_cmd = sprintf('"%s" -S "%s" -B "%s" -DCMAKE_INSTALL_PREFIX="%s" -DBUILD_STATIC=ON -DBUILD_TESTS=OFF -DWITH_LIBSODIUM=OFF', ...
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
    fprintf('Deleting existing file: %s\n', output_file);
    delete(output_file);
end

% Construct the mex command
ZMQ_INC_DIR_BUILT = fullfile(ZMQ_INSTALL_DIR, 'include');
ZMQ_LIB_DIR_BUILT = fullfile(ZMQ_INSTALL_DIR, 'lib');

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
