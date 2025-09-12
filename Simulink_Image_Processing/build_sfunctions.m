function build_sfunctions()
% build_sfunctions - Compiles the ZMQ S-Function MEX files from source.
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
fprintf('Building S-Function MEX files...\n');

% 1. Find CMake executable
cmake_exe = find_cmake(CMAKE_INSTALL_DIR);
if isempty(cmake_exe)
    error('CMake not found. Please run build.ps1 from an Administrator PowerShell prompt to ensure all dependencies are set up correctly.');
end

% 2. Build ZeroMQ library using CMake
fprintf('--- Building ZeroMQ library from source ---\n');
if exist(ZMQ_BUILD_DIR, 'dir')
    fprintf('Cleaning previous build directory...\n');
    rmdir(ZMQ_BUILD_DIR, 's');
end
mkdir(ZMQ_BUILD_DIR);

compiler_cfg = mex.getCompilerConfigurations('C++', 'Selected');
if isempty(compiler_cfg)
    error('No C++ compiler is selected in MATLAB. Please run "mex -setup C++".');
end

% Configure CMake command
cmake_configure_cmd = sprintf('"%s" -S "%s" -B "%s" -A x64 -DCMAKE_INSTALL_PREFIX="%s" -DBUILD_SHARED=ON -DBUILD_STATIC=OFF -DBUILD_TESTS=OFF -DWITH_LIBSODIUM=OFF', ...
    cmake_exe, ZMQ_SOURCE_DIR, ZMQ_BUILD_DIR, ZMQ_INSTALL_DIR);

% Build command
cmake_build_cmd = sprintf('"%s" --build "%s" --config Release --target install', cmake_exe, ZMQ_BUILD_DIR);

% Execute CMake commands
fprintf('Configuring ZeroMQ build...\n');
[status, cmdout] = system(cmake_configure_cmd);
if status ~= 0, disp(cmdout); error('CMake configuration failed.'); end

fprintf('Building and installing ZeroMQ...\n');
[status, cmdout] = system(cmake_build_cmd);
if status ~= 0, disp(cmdout); error('ZeroMQ build failed.'); end
fprintf('--- ZeroMQ library built successfully ---\n');


% 3. Build the S-Function MEX files
fprintf('--- Building S-Function MEX files ---\n');
S_FUNCTION_SOURCES = { ...
    'sfun_zeromq_image.cpp', ...
    'sfun_zeromq_control.cpp' ...
};

ZMQ_INC_DIR_BUILT = fullfile(ZMQ_INSTALL_DIR, 'include');
ZMQ_LIB_DIR_BUILT = fullfile(ZMQ_INSTALL_DIR, 'lib');
MEX_COMMON_INC_DIR = fullfile(PROJECT_ROOT, 'ThirdParty', 'include');

lib_file = dir(fullfile(ZMQ_LIB_DIR_BUILT, '*zmq*.lib'));
if isempty(lib_file), error('Could not find built ZeroMQ library file.'); end
[~, lib_name, ~] = fileparts(lib_file(1).name);

for i = 1:length(S_FUNCTION_SOURCES)
    src_filename = S_FUNCTION_SOURCES{i};
    [~, output_name, ~] = fileparts(src_filename);
    
    src_file_path = fullfile(PROJECT_ROOT, 'c_src', src_filename);
    output_file_path = fullfile(PROJECT_ROOT, [output_name, '.', mexext]);
    
    fprintf('\n--- Building %s ---\n', src_filename);
    
    if exist(output_file_path, 'file')
        fprintf('Deleting existing MEX file: %s\n', output_file_path);
        delete(output_file_path);
    end
    
    % Check if using MinGW compiler and adjust library linking accordingly
    if contains(compiler_cfg.Name, 'MinGW')
        % For MinGW, use the system libraries from MinGW installation
        mingw_root = getenv('MW_MINGW64_LOC');
        if ~isempty(mingw_root)
            mingw_lib_path = fullfile(mingw_root, 'x86_64-w64-mingw32', 'lib');
        else
            mingw_lib_path = '';
        end
        
        mex_command = { ...
            '-v', ...
            ['-I"' ZMQ_INC_DIR_BUILT '"'], ...
            ['-I"' MEX_COMMON_INC_DIR '"'], ...
            ['-L"' ZMQ_LIB_DIR_BUILT '"'], ...
            ['-l' lib_name], ...
            '-lws2_32', ...
            '-liphlpapi', ...
            ['"' src_file_path '"'], ...
            '-output', ['"' output_file_path '"'] ...
        };
        
        % Add MinGW library path if found
        if ~isempty(mingw_lib_path) && exist(mingw_lib_path, 'dir')
            mex_command = [mex_command(1:end-2), {['-L"' mingw_lib_path '"']}, mex_command(end-1:end)];
        end
    else
        % For MSVC, use the original approach
        mex_command = { ...
            '-v', ...
            ['-I"' ZMQ_INC_DIR_BUILT '"'], ...
            ['-I"' MEX_COMMON_INC_DIR '"'], ...
            ['-L"' ZMQ_LIB_DIR_BUILT '"'], ...
            ['-l' lib_name], ...
            '-lws2_32', ...
            '-liphlpapi', ...
            'COMPFLAGS="$COMPFLAGS /std:c++17 /MT"', ...
            ['"' src_file_path '"'], ...
            '-output', ['"' output_file_path '"'] ...
        };
    end
    
    try
        mex(mex_command{:});
        fprintf('Successfully built %s.\n', output_file_path);
    catch ME
        fprintf('Error building %s:\n', src_file_path);
        rethrow(ME);
    end
end

fprintf('\nAll S-Functions built successfully.\n');

% 4. Copy ZeroMQ DLL to the project root directory
fprintf('--- Copying ZeroMQ DLL to project root ---\n');
% The DLL is typically in the 'bin\Release' directory of the build output
ZMQ_DLL_DIR = fullfile(ZMQ_BUILD_DIR, 'bin', 'Release');
dll_file = dir(fullfile(ZMQ_DLL_DIR, '*zmq*.dll'));
if isempty(dll_file)
    warning('Could not find built ZeroMQ DLL file. Runtime errors may occur.');
else
    source_dll = fullfile(dll_file(1).folder, dll_file(1).name);
    destination_dll = fullfile(PROJECT_ROOT, dll_file(1).name);
    copyfile(source_dll, destination_dll, 'f');
    fprintf('Successfully copied %s to project root.\n', dll_file(1).name);
end

end

function cmake_path = find_cmake(local_cmake_dir)
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
