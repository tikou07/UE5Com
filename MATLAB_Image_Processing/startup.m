% startup.m for MATLAB_Image_Processing
%
% This script configures the MATLAB environment for this project.
% Run this script once after starting MATLAB.

fprintf('Setting up environment for MATLAB_Image_Processing...\n');

% Get the full path to the project's root directory
projectRoot = fileparts(mfilename('fullpath'));
fprintf('Project Root: %s\n', projectRoot);

% --- Add project folders to MATLAB path ---
fprintf('Adding project source folders to path...\n');
addpath(fullfile(projectRoot)); % Add root for scripts like build_mex_files
addpath(fullfile(projectRoot, 'mex'));

% --- Configure Python Environment ---
fprintf('Configuring Python environment...\n');
pythonRuntimeDir = fullfile(projectRoot, 'python_runtime');
pythonExe = fullfile(pythonRuntimeDir, 'python.exe');

if isfolder(pythonRuntimeDir) && isfile(pythonExe)
    fprintf('Found Python executable at: %s\n', pythonExe);
    try
        pyenv('Version', pythonExe);
        fprintf('Successfully configured MATLAB to use the local Python environment.\n');
        
        % Optional: Display Python version to confirm
        pyVer = pyversion;
        fprintf('Python Version: %s\n', pyVer);
        
    catch ME
        warning('Failed to set Python environment. Please check your MATLAB Python configuration.');
        warning(ME.message);
    end
else
    warning('Local Python runtime not found. Please run setup_environment.ps1 first.');
    fprintf('Expected Python executable at: %s\n', pythonExe);
end

fprintf('Environment setup complete.\n');
