% Add necessary subfolders to the MATLAB path for this project

fprintf('Adding project folders to MATLAB path...\n');

% Get the directory where this script is located
project_root = fileparts(mfilename('fullpath'));

% Add project root to path (for slblocks.m)
addpath(project_root);

% Add source folders
addpath(fullfile(project_root, 'c_src'));
addpath(fullfile(project_root, 'm_src'));
addpath(fullfile(project_root, 'mask'));
addpath(fullfile(project_root, 'help'));

% Add ThirdParty include folder if needed for headers, etc.
addpath(fullfile(project_root, 'ThirdParty', 'include'));

fprintf('Paths added successfully.\n');
