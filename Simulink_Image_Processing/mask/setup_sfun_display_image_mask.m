function setup_sfun_display_image_mask(block)
% This script creates a mask for the 'sfun_display_image' S-Function block.
% If no block path is provided, it acts on the currently selected block (gcb).
%
% To use it manually:
% 1. Open your Simulink model.
% 2. Select the 'sfun_display_image' block.
% 3. Run this script from the MATLAB command window.

% If no block path is provided, get the currently selected block
if nargin < 1 || isempty(block)
    block = gcb;
end

% Check if a block is selected or provided
if isempty(block) || ~ischar(block) && ~ishandle(block)
    error('No block provided or selected. Please provide a block path or select a block.');
end

% Check if the selected block is the correct S-Function
sfun_name = get_param(block, 'FunctionName');
if ~strcmp(sfun_name, 'sfun_display_image')
    error('This script is intended for "sfun_display_image". The selected block is "%s".', sfun_name);
end

% --- Create Mask ---
% Remove existing mask if any
maskObj = Simulink.Mask.get(block);
if ~isempty(maskObj)
    maskObj.delete();
end

% Create a new mask
mask = Simulink.Mask.create(block);
mask.Description = 'Displays an image vector from Simulink in a MATLAB figure window.';
mask.Type = 'Image Display';

% --- Add Parameters to the Mask Dialog ---
% Create a tab container
tabContainer = mask.addDialogControl('Type', 'tabcontainer', 'Name', 'TabContainer');

% Create tabs within the container
tab1 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'ImageTab', 'Prompt', 'Image');
tab2 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'DisplayTab', 'Prompt', 'Display');

% -- Image Parameters --
param = mask.addParameter('Type', 'edit', 'Name', 'imgHeight', 'Prompt', 'Image Height:');
param.Container = 'ImageTab';
param.Value = '1024';

param = mask.addParameter('Type', 'edit', 'Name', 'imgWidth', 'Prompt', 'Image Width:');
param.Container = 'ImageTab';
param.Value = '1024';

param = mask.addParameter('Type', 'popup', 'Name', 'channels', 'Prompt', 'Channels:');
param.Container = 'ImageTab';
param.TypeOptions = {'3 (RGB)', '1 (Grayscale)'};
param.Value = '3 (RGB)';

% -- Display Parameters --
param = mask.addParameter('Type', 'edit', 'Name', 'title', 'Prompt', 'Figure Title:', 'Evaluate', 'off');
param.Container = 'DisplayTab';
param.Value = 'ZeroMQ Image Display';

param = mask.addParameter('Type', 'edit', 'Name', 'decimation', 'Prompt', 'Update Decimation (every Nth frame):');
param.Container = 'DisplayTab';
param.Value = '1';

param = mask.addParameter('Type', 'edit', 'Name', 'sample_time', 'Prompt', 'Sample Time (-1 for inherited):');
param.Container = 'DisplayTab';
param.Value = '1';


% --- Set Initialization Code ---
% The S-Function now reads directly from the mask parameters,
% so no initialization code is needed.
mask.Initialization = '';


% --- Set Display Code ---
% This code determines what is shown on the block icon.
display_code_cell = { ...
    'port_label(''input'', 1, ''Img'');', ...
    'sprintf(''Display\\n%s x %s'', imgWidth, imgHeight);' ...
};
mask.Display = strjoin(display_code_cell, newline);

% --- Set Help Text ---
help_file_path = fullfile(fileparts(mfilename('fullpath')), '..', 'help', 'sfun_display_image_help.html');
mask.Help = sprintf('web(''%s'');', help_file_path);

disp('Mask for sfun_display_image has been created/updated successfully.');
disp('Please save your Simulink model to retain the changes.');

end
