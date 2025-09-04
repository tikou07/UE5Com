function build_mex_files()
% build_mex_files - Compiles the ZMQ handler MEX file for the project.

% --- Clear any loaded MEX files ---
clear mex;

% --- Configuration ---
ZMQ_INC_DIR = fullfile('ThirdParty', 'include');
ZMQ_LIB_DIR = fullfile('ThirdParty', 'lib', 'Win64');
ZMQ_LIB_NAME = 'zmq-v143-mt-s-4_3_5'; % Static library name

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

% Construct the mex command
mex_command = { ...
    '-v', ... % Verbose output
    ['-I' ZMQ_INC_DIR], ...
    ['-L' ZMQ_LIB_DIR], ...
    ['-l' ZMQ_LIB_NAME], ...
    'COMPFLAGS="$COMPFLAGS /MT"', ... % Static linking
    SRC_FILE, ...
    '-output', output_file ...
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
