function setup_library()
% setup_library - Copies necessary runtime libraries for the MEX files.
%
% This script ensures that the required ZeroMQ DLL is available in the
% same directory as the compiled MEX files, which is necessary for them
% to run correctly.

% --- Configuration ---
DLL_SOURCE_DIR = fullfile('..', 'Simulink_Image_Processing', 'ThirdParty', 'bin', 'Win64');
DLL_NAME = 'libzmq-mt-4_3_5.dll';
DEST_DIR = fullfile(pwd, 'mex');

DLL_SOURCE_PATH = fullfile(DLL_SOURCE_DIR, DLL_NAME);
DEST_PATH = fullfile(DEST_DIR, DLL_NAME);

fprintf('Setting up required libraries...\n');

% --- Pre-check ---
if ~exist(DLL_SOURCE_PATH, 'file')
    error('Required DLL not found at: %s\nPlease ensure the Simulink_Image_Processing directory is intact.', DLL_SOURCE_PATH);
end

if ~exist(DEST_DIR, 'dir')
    fprintf('Creating destination directory: %s\n', DEST_DIR);
    mkdir(DEST_DIR);
end

% --- Copy DLL ---
try
    fprintf('Copying %s to %s...\n', DLL_NAME, DEST_DIR);
    copyfile(DLL_SOURCE_PATH, DEST_DIR, 'f');
    fprintf('Library setup complete.\n');
catch ME
    fprintf('Error during library setup:\n');
    rethrow(ME);
end

end
