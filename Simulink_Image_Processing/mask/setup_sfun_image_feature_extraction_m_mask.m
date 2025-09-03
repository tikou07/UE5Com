function setup_sfun_image_feature_extraction_m_mask(block)
% Mask setup for the sfun_image_feature_extraction_m S-Function.
% This script defines the user interface (dialog controls) for the block.
%
% To use it manually:
% 1. Open your Simulink model.
% 2. Select the 'sfun_image_feature_extraction_m' block.
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
if ~strcmp(sfun_name, 'sfun_image_feature_extraction_m')
    error('This script is intended for "sfun_image_feature_extraction_m". The selected block is "%s".', sfun_name);
end

% --- Create Mask ---
% Remove existing mask if any
maskObj = Simulink.Mask.get(block);
if ~isempty(maskObj)
    maskObj.delete();
end

% Create a new mask
mask = Simulink.Mask.create(block);
mask.Description = 'Extracts image features using Python OpenCV. Configures image properties, feature extraction parameters, and logging via a user-friendly interface.';
mask.Type = 'Image Feature Extraction';

% --- Add Parameters to the Mask Dialog ---
% Create a tab container
tabContainer = mask.addDialogControl('Type', 'tabcontainer', 'Name', 'TabContainer');

% Create tabs within the container
tab1 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'ImageTab', 'Prompt', 'Image');
tab2 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'FeatureTab', 'Prompt', 'Feature Extraction');
tab3 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'BlockTab', 'Prompt', 'Block');
tab4 = tabContainer.addDialogControl('Type', 'tab', 'Name', 'DebuggingTab', 'Prompt', 'Debugging');

% -- Image Parameters --
param = mask.addParameter('Type', 'edit', 'Name', 'imgHeight', 'Prompt', 'Image Height:');
param.Container = 'ImageTab';
param.Value = '1024';

param = mask.addParameter('Type', 'edit', 'Name', 'imgWidth', 'Prompt', 'Image Width:');
param.Container = 'ImageTab';
param.Value = '1024';

param = mask.addParameter('Type', 'edit', 'Name', 'channels', 'Prompt', 'Image Channels (must be 3):');
param.Container = 'ImageTab';
param.Value = '3';

% -- Feature Extraction Parameters --
param = mask.addParameter('Type', 'popup', 'Name', 'processingMode', 'Prompt', 'Processing Mode:');
param.Container = 'FeatureTab';
param.TypeOptions = {'ORB Features', 'Binarization & Centroids'};
param.Value = 'ORB Features';

param = mask.addParameter('Type', 'edit', 'Name', 'nfeatures', 'Prompt', 'Max Features (ORB):');
param.Container = 'FeatureTab';
param.Value = '500';

param = mask.addParameter('Type', 'edit', 'Name', 'threshold', 'Prompt', 'Binarization Threshold (0-255):');
param.Container = 'FeatureTab';
param.Value = '127';

% -- Block Parameters --
param = mask.addParameter('Type', 'edit', 'Name', 'sample_time', 'Prompt', 'Sample Time (-1 for inherited):');
param.Container = 'BlockTab';
param.Value = '-1';

% -- Debugging Parameters --
param = mask.addParameter('Type', 'checkbox', 'Name', 'enable_logging', 'Prompt', 'Enable Diagnostic Logging');
param.Container = 'DebuggingTab';
param.Value = 'on';

% --- Mask Display ---
% This defines how the block appears in the Simulink model.
mask.Display = [ ...
    'fprintf(''Image Feature\nExtraction\n(Python OpenCV)'');' ...
    'port_label(''input'', 1, ''Img'');' ...
    'port_label(''output'', 1, ''ImgFeat'');' ...
    'port_label(''output'', 2, ''Features'');' ...
];

% --- Set Initialization Code ---
% This code constructs the S-Function's 'Parameters' string from the mask values.
mask.Initialization = sprintf('%s;%s;%s', ...
  'if strcmp(get_param(gcb,''enable_logging''),''on''), enable_logging_val=1; else, enable_logging_val=0; end', ...
  'if strcmp(get_param(gcb,''processingMode''),''ORB Features''), processing_mode_val=1; else, processing_mode_val=2; end', ...
  ['params_str = sprintf(''%s, %s, %s, %s, %s, %d, %d, %s'', ', ...
     'get_param(gcb,''imgHeight''), get_param(gcb,''imgWidth''), ', ...
     'get_param(gcb,''channels''), get_param(gcb,''nfeatures''), ', ...
     'get_param(gcb,''sample_time''), enable_logging_val, processing_mode_val, ', ...
     'get_param(gcb,''threshold''));'], ...
  'set_param(gcb,''Parameters'', params_str)' );

% --- Set Display Code ---
% This code determines what is shown on the block icon.
display_code_cell = { ...
    'port_label(''input'', 1, ''Img'');', ...
    'port_label(''output'', 1, ''ImgFeat'');', ...
    'port_label(''output'', 2, ''Features'');', ...
    'sprintf(''Image Feature\\nExtraction\\n(Python OpenCV)'');' ...
};
mask.Display = strjoin(display_code_cell, newline);

% --- Set Help Text ---
help_file_path = fullfile(fileparts(mfilename('fullpath')), '..', 'help', 'sfun_image_feature_extraction_m_help.html');
mask.Help = sprintf('web(''%s'');', help_file_path);

disp('Mask for sfun_image_feature_extraction_m has been created/updated successfully.');
disp('Please save your Simulink model to retain the changes.');

end
