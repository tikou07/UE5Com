function setup_sfun_zeromq_image_mask(block)
% This script creates a mask for the 'sfun_zeromq_image' S-Function block.
% If no block path is provided, it acts on the currently selected block (gcb).
%
% To use it manually:
% 1. Open your Simulink model.
% 2. Select the 'sfun_zeromq_image' block.
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
if ~strcmp(sfun_name, 'sfun_zeromq_image')
    error('This script is intended for "sfun_zeromq_image". The selected block is "%s".', sfun_name);
end

% --- Create Mask ---
% Remove existing mask if any
maskObj = Simulink.Mask.get(block);
if ~isempty(maskObj)
    maskObj.delete();
end

% Create a new mask
mask = Simulink.Mask.create(block);
mask.Description = 'Receives images from a ZeroMQ publisher. Configures connection, image properties, and logging via a user-friendly interface.';
mask.Type = 'ZeroMQ Image Receiver';

% --- Add Parameters to the Mask Dialog ---
% Create a tab container
tabContainer = mask.addDialogControl('Type', 'tabcontainer', 'Name', 'TabContainer');

% Create tabs within the container
tab1 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'ConnectionTab', 'Prompt', 'Connection');
tab2 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'ImageTab', 'Prompt', 'Image');
tab3 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'BlockTab', 'Prompt', 'Block');
tab4 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'DebuggingTab', 'Prompt', 'Debugging');

% -- Connection Parameters --
param = mask.addParameter('Type', 'edit', 'Name', 'address', 'Prompt', 'Address:', 'Evaluate', 'off');
param.Container = 'ConnectionTab';
param.Value = 'tcp://127.0.0.1:5555';

param = mask.addParameter('Type', 'edit', 'Name', 'camera_id', 'Prompt', 'Camera ID (Topic):', 'Evaluate', 'off');
param.Container = 'ConnectionTab';
param.Value = 'Camera01';

param = mask.addParameter('Type', 'checkbox', 'Name', 'bind_mode', 'Prompt', 'Bind (Listen) Mode');
param.Container = 'ConnectionTab';
param.Value = 'off';

param = mask.addParameter('Type', 'edit', 'Name', 'timeout_ms', 'Prompt', 'Receive Timeout (ms):');
param.Container = 'ConnectionTab';
param.Value = '1000';

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

% -- Block Parameters --
param = mask.addParameter('Type', 'edit', 'Name', 'sample_time', 'Prompt', 'Sample Time (-1 for inherited):');
param.Container = 'BlockTab';
param.Value = '1';

% -- Debugging Parameters --
param = mask.addParameter('Type', 'checkbox', 'Name', 'enable_logging', 'Prompt', 'Enable Console Logging');
param.Container = 'DebuggingTab';
param.Value = 'off';


% --- Set Initialization Code ---
% This code constructs the S-Function's 'Parameters' string from the mask values.
% It uses a single sprintf call to create a robust, multi-line initialization command.
mask.Initialization = sprintf('%s;%s;%s;%s;%s;%s', ...
  'if strcmp(get_param(gcb,''bind_mode''),''on''), bind_mode_str=''true''; else, bind_mode_str=''false''; end', ...
  'if strcmp(get_param(gcb,''channels''),''3 (RGB)''), channel_num_str=''3''; else, channel_num_str=''1''; end', ...
  'if strcmp(get_param(gcb,''enable_logging''),''on''), enable_logging_str=''true''; else, enable_logging_str=''false''; end', ...
  'qs = char(39);', ...
  ['fmt = [qs ''%s'' qs '', '' qs ''%s'' qs '', %s, %s, %s, %s, %s, %s, %s''];'], ...
  ['params_str = sprintf(fmt, get_param(gcb,''address''), get_param(gcb,''camera_id''), ', ...
     'bind_mode_str, get_param(gcb,''timeout_ms''), get_param(gcb,''imgHeight''), ', ...
     'get_param(gcb,''imgWidth''), channel_num_str, get_param(gcb,''sample_time''), ', ...
     'enable_logging_str);'], ...
  'set_param(gcb,''Parameters'', params_str)' );


% --- Set Display Code ---
% This code determines what is shown on the block icon.
display_code_cell = { ...
    'port_label(''output'', 1, ''Img'');', ...
    'sprintf(''ZMQ Image\\n%s\\n%s'', address, camera_id);' ...
};
mask.Display = strjoin(display_code_cell, newline);

% --- Set Help Text ---
% This command constructs a relative path from this mask script to the help HTML file.
% This is more robust than relying on the block's path within the model.
help_file_path = fullfile(fileparts(mfilename('fullpath')), '..', 'help', 'sfun_zeromq_image_help.html');
mask.Help = sprintf('web(''%s'');', help_file_path);

disp('Mask for sfun_zeromq_image has been created/updated successfully.');
disp('Please save your Simulink model to retain the changes.');

end
