function build_mex_files()
% build_mex_files - Compiles the ZMQ handler MEX file for the project.

% --- Clear any loaded MEX files ---
clear mex;

% --- Configuration ---
ZMQ_INC_DIR = fullfile('ThirdParty', 'include');
ZMQ_LIB_DIR_MSVC = fullfile('ThirdParty', 'lib', 'Win64'); % For MSVC (.lib)
ZMQ_LIB_DIR_MINGW = fullfile('ThirdParty', 'lib', 'Win64-MinGW'); % For MinGW (.a)
ZMQ_LIB_NAME_MSVC = 'zmq-v143-mt-s-4_3_5'; % Static library name for MSVC
ZMQ_LIB_NAME_MINGW = 'zmq';    % Library name for MinGW (links against libzmq.a)

% --- Source File ---
SRC_FILE = fullfile('c_src', 'mex_zeromq_handler.cpp');
OUTPUT_NAME = 'mex_zeromq_handler';

% --- Build Command ---
fprintf('Building MEX file for %s...\n', SRC_FILE);

% Create output directory if it doesn't exist
if ~exist('mex', 'dir')
    mkdir('mex');
end

output_file = fullfile('mex', [OUTPUT_NAME, '.', mexext]);
% Delete existing MEX file to avoid linking errors
if exist(output_file, 'file')
    fprintf('Deleting existing file: %s\n', output_file);
    delete(output_file);
end

% Determine which compiler is being used
compiler_cfg = mex.getCompilerConfigurations('C++', 'Selected');
is_mingw = contains(compiler_cfg.Name, 'MinGW');

% Construct the mex command
base_mex_command = { ...
    '-v', ... % Verbose output
    ['-I' ZMQ_INC_DIR] ...
};

% Add compiler-specific flags
if is_mingw
    % For MinGW, link against the newly added .a file
    fprintf('MinGW compiler detected. Linking against libzmq.a.\n');
    compiler_specific_flags = { ...
        ['-L' ZMQ_LIB_DIR_MINGW], ...
        ['-l' ZMQ_LIB_NAME_MINGW] ...
    };
else
    % For MSVC, specify static library path and name
    fprintf('MSVC compiler detected. Linking against static LIB.\n');
    compiler_specific_flags = { ...
        ['-L' ZMQ_LIB_DIR_MSVC], ...
        ['-l' ZMQ_LIB_NAME_MSVC], ...
        'COMPFLAGS="$COMPFLAGS /MT"' ...
    };
end

% Combine all parts of the command
mex_command = [base_mex_command, compiler_specific_flags, {SRC_FILE, '-output', output_file}];

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
