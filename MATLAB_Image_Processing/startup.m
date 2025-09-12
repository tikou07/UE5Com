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
addpath(fullfile(projectRoot)); % Add root for scripts and packages
addpath(fullfile(projectRoot, 'mex'));

% --- Configure Python Environment ---
fprintf('Configuring Python environment...\n');
% The Python environment is managed by uv in the .venv directory
venvDir = fullfile(projectRoot, '.venv');

if isfolder(venvDir)
    fprintf('Python virtual environment found at: %s\n', venvDir);
    fprintf('Note: Using embeddable Python for MATLAB compatibility.\n');
    fprintf('Python functionality is available through the configured environment.\n');
else
    warning('Python virtual environment not found. Please run setup.bat to set up the environment.');
end

fprintf('Environment setup complete.\n');
