function setup_sfun_zeromq_control_mask(block)
% This script creates a mask for the 'sfun_zeromq_control' S-Function block.
% If no block path is provided, it acts on the currently selected block (gcb).
%
% To use it manually:
% 1. Open your Simulink model.
% 2. Select the 'sfun_zeromq_control' block.
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
if ~strcmp(sfun_name, 'sfun_zeromq_control')
    error('This script is intended for "sfun_zeromq_control". The selected block is "%s".', sfun_name);
end

% --- Create Mask ---
% Remove existing mask if any
maskObj = Simulink.Mask.get(block);
if ~isempty(maskObj)
    maskObj.delete();
end

% Create a new mask
mask = Simulink.Mask.create(block);
mask.Description = 'Publishes actor transform commands via ZeroMQ.';
mask.Type = 'ZeroMQ Control Publisher';

% --- Add Parameters to the Mask Dialog ---
param = mask.addParameter('Type', 'edit', 'Name', 'address', 'Prompt', 'Address:', 'Evaluate', 'off');
param.Value = 'tcp://127.0.0.1:5556';

param = mask.addParameter('Type', 'edit', 'Name', 'target_id_default', 'Prompt', 'Default Target ID:', 'Evaluate', 'off');
param.Value = 'Camera01';

param = mask.addParameter('Type', 'edit', 'Name', 'sample_time', 'Prompt', 'Sample Time (-1 for inherited):');
param.Value = '0.0625';

param = mask.addParameter('Type', 'checkbox', 'Name', 'enable_logging', 'Prompt', 'Enable Console Logging');
param.Value = 'off';


% --- Set Initialization Code ---
% This code constructs the S-Function's 'Parameters' string from the mask values.
% It uses a single sprintf call to create a robust, multi-line initialization command.
mask.Initialization = sprintf('%s;%s;%s;%s;%s', ...
  'if strcmp(get_param(gcb,''enable_logging''),''on''), enable_logging_str=''true''; else, enable_logging_str=''false''; end', ...
  'qs = char(39);', ...
  ['fmt = [qs ''%s'' qs '', '' qs ''%s'' qs '', %s, %s''];'], ...
  ['params_str = sprintf(fmt, get_param(gcb,''address''), get_param(gcb,''target_id_default''), ', ...
     'get_param(gcb,''sample_time''), enable_logging_str);'], ...
  'set_param(gcb,''Parameters'', params_str)' );


% --- Set Display Code ---
% This code determines what is shown on the block icon.
display_code_cell = { ...
    'port_label(''input'', 1, ''x'');', ...
    'port_label(''input'', 2, ''y'');', ...
    'port_label(''input'', 3, ''z'');', ...
    'port_label(''input'', 4, ''roll'');', ...
    'port_label(''input'', 5, ''pitch'');', ...
    'port_label(''input'', 6, ''yaw'');', ...
    'sprintf(''ZMQ Control\\n%s\\n%s'', address, target_id_default);' ...
};
mask.Display = strjoin(display_code_cell, newline);

% --- Set Help Text ---
help_file_path = fullfile(fileparts(mfilename('fullpath')), '..', 'help', 'sfun_zeromq_control_help.html');
mask.Help = sprintf('web(''%s'');', help_file_path);

disp('Mask for sfun_zeromq_control has been created/updated successfully.');
disp('Please save your Simulink model to retain the changes.');

end
