function sfun_display_image(block)
% Level-2 MATLAB S-Function to display images received in Simulink.
%
% This block accepts a uint8 column vector of size (H*W*C x 1) on its
% single input port and displays it in a MATLAB figure in real-time.
%
% Dialog parameters (in order):
% 1) imgHeight (int) default 1024
% 2) imgWidth  (int) default 1024
% 3) channels  (int) 1 or 3, default 3
% 4) sample_time (double) -1 = inherit, >=0 = fixed sample time (default 0.1)
% 5) title (string, optional) figure title (default 'ZeroMQ Image Display')
% 6) decimation (int, optional) update every Nth call (default 1)
%
% Notes:
% - Intended for debugging / visualization only. Frequent GUI updates
%   may impact Simulink performance. Use sample_time and decimation to
%   reduce update frequency if needed.

setup(block);

end

% ----------------------------------------------------------
function setup(block)
  % Register number of dialog parameters
  block.NumDialogPrms = 6;

  % One input port, no outputs
  block.NumInputPorts  = 1;
  block.NumOutputPorts = 0;

  % Check if a mask is applied. If so, read parameters from the mask.
  % Otherwise, fall back to legacy dialog parameters.
  hasMask = ~isempty(get_param(block.BlockHandle, 'MaskType'));

  if hasMask
      % Read parameters from mask
      imgH         = str2double(get_param(block.BlockHandle, 'imgHeight'));
      imgW         = str2double(get_param(block.BlockHandle, 'imgWidth'));
      channels_str = get_param(block.BlockHandle, 'channels');
      if strcmp(channels_str, '3 (RGB)')
          channels = 3;
      else
          channels = 1;
      end
      sample_time  = str2double(get_param(block.BlockHandle, 'sample_time'));
      fig_title    = get_param(block.BlockHandle, 'title');
      decimation   = str2double(get_param(block.BlockHandle, 'decimation'));
  else
      % Fallback to legacy dialog parameters
      try
          imgH = double(block.DialogPrm(1).Data);
      catch
          imgH = 1024;
      end
      try
          imgW = double(block.DialogPrm(2).Data);
      catch
          imgW = 1024;
      end
      try
          channels = double(block.DialogPrm(3).Data);
      catch
          channels = 3;
      end
      try
          sample_time = double(block.DialogPrm(4).Data);
      catch
          sample_time = 0.1;
      end
      try
          fig_title = char(block.DialogPrm(5).Data);
      catch
          fig_title = 'ZeroMQ Image Display';
      end
      try
          decimation = double(block.DialogPrm(6).Data);
      catch
          decimation = 1;
      end
  end
  if isempty(decimation) || decimation < 1
      decimation = 1;
  end

  % Validate channels
  if ~(channels == 1 || channels == 3)
      error('sfun_display_image: channels must be 1 or 3');
  end

  % Configure input port dimensions and datatype
  inLen = imgH * imgW * channels;
  block.InputPort(1).Dimensions = inLen;
  block.InputPort(1).DatatypeID = -1; % attempt to be flexible; we'll cast in Outputs
  block.InputPort(1).DirectFeedthrough = false;
  block.InputPort(1).SamplingMode = 'Sample';

  % Apply sample time
  if ~isempty(sample_time) && sample_time >= 0
      block.SampleTimes = [sample_time 0];
  else
      block.SampleTimes = [-1 0];
  end

  block.SimStateCompliance = 'DefaultSimState';

  % Register methods
  block.RegBlockMethod('Start',     @Start);
  block.RegBlockMethod('Outputs',   @Outputs);
  block.RegBlockMethod('Terminate', @Terminate);

  % Initialize UserData
  ud.imgH = imgH;
  ud.imgW = imgW;
  ud.channels = channels;
  ud.decimation = decimation;
  ud.title = fig_title;
  ud.updateCounter = 0;
  % lastImage stores the last displayed image as uint8
  ud.lastImage = zeros(imgH, imgW, max(1,channels), 'uint8');

  setBlockRuntimeData(block, ud);
end

% ----------------------------------------------------------
function Start(block)
  ud = getBlockRuntimeData(block);
  % Ensure fields exist
  if ~isfield(ud, 'imgH'), ud.imgH = 1024; end
  if ~isfield(ud, 'imgW'), ud.imgW = 1024; end
  if ~isfield(ud, 'channels'), ud.channels = 3; end
  if ~isfield(ud, 'decimation'), ud.decimation = 1; end
  if ~isfield(ud, 'title'), ud.title = 'ZeroMQ Image Display'; end
  if ~isfield(ud, 'updateCounter'), ud.updateCounter = 0; end
  if ~isfield(ud, 'lastImage') || numel(ud.lastImage) ~= ud.imgH*ud.imgW*max(1,ud.channels)
      ud.lastImage = zeros(ud.imgH, ud.imgW, max(1,ud.channels), 'uint8');
  end

  % Create figure and image handle for display
  try
      % Create non-blocking figure, do not create new toolstrip windows when used in deployed MATLAB.
      ud.fig = figure('Name', ud.title, 'NumberTitle', 'off', 'Visible', 'on');
      ud.ax = axes('Parent', ud.fig);
      % Create initial image
      if ud.channels == 1
          ud.hImg = image(ud.lastImage, 'Parent', ud.ax);
          colormap(ud.ax, gray(256));
      else
          ud.hImg = image(ud.lastImage, 'Parent', ud.ax);
      end
      axis(ud.ax, 'image');
      axis(ud.ax, 'off');
      drawnow;
  catch ME
      % If figure creation fails, log warning and continue; block will still run but no display.
      try
          fprintf('[sfun_display_image] Warning: failed to create figure: %s\n', ME.message);
      catch
      end
      ud.fig = [];
      ud.ax = [];
      ud.hImg = [];
  end

  setBlockRuntimeData(block, ud);
end

% ----------------------------------------------------------
function Outputs(block)
  ud = getBlockRuntimeData(block);
  % Read input vector
  try
      inVec = block.InputPort(1).Data;
  catch
      inVec = [];
  end

  % Ensure inVec is numeric and non-empty
  if isempty(inVec)
      % nothing received; keep last image
      return;
  end

  % Cast to uint8 safely
  try
      inVec = uint8(inVec(:)); % ensure column
  catch
      try
          inVec = uint8(double(inVec(:)));
      catch
          % can't cast; keep last
          return;
      end
  end

  expectedLen = ud.imgH * ud.imgW * max(1,ud.channels);
  if numel(inVec) ~= expectedLen
      % Size mismatch; try to adjust: truncate or pad
      if numel(inVec) > expectedLen
          inVec = inVec(1:expectedLen);
      else
          inVec = [inVec; zeros(expectedLen - numel(inVec), 1, 'uint8')];
      end
  end

  % Reshape into image, converting from C-style row-major pixel stream to MATLAB's HxWx_C matrix
  try
      % Reshape to [channels, width, height]
      im_reshaped = reshape(inVec, [ud.channels, ud.imgW, ud.imgH]);
      % Permute to [height, width, channels]
      im = permute(im_reshaped, [3, 2, 1]);
  catch
      % fallback: create blank image
      im = ud.lastImage;
  end

  % Update decimation counter and decide whether to redraw
  ud.updateCounter = ud.updateCounter + 1;
  redraw = (mod(ud.updateCounter - 1, ud.decimation) == 0);

  if redraw && ~isempty(ud.hImg) && ishandle(ud.hImg)
      try
          % Update displayed image
          set(ud.hImg, 'CData', im);
          % Use limited drawnow to avoid blocking too long
          drawnow limitrate;
      catch ME
          try
              fprintf('[sfun_display_image] Error updating image: %s\n', ME.message);
          catch
          end
      end
  end

  % Save last image
  ud.lastImage = im;
  setBlockRuntimeData(block, ud);
end

% ----------------------------------------------------------
function Terminate(block)
  ud = getBlockRuntimeData(block);
  try
      if isfield(ud, 'hImg') && ~isempty(ud.hImg) && ishandle(ud.hImg)
          try
              delete(ud.hImg);
          catch
          end
      end
      if isfield(ud, 'fig') && ~isempty(ud.fig) && ishandle(ud.fig)
          try
              close(ud.fig);
          catch
          end
      end
  catch ME
      try
          fprintf('[sfun_display_image] Terminate error: %s\n', ME.message);
      catch
      end
  end
end

% ----------------------------------------------------------
% Helper functions for storing runtime data (copied pattern used by other S-Functions)
function setBlockRuntimeData(block, ud)
  try
      block.UserData = ud;
  catch
      global sfun_display_shared;
      if isempty(sfun_display_shared) || ~isstruct(sfun_display_shared)
          sfun_display_shared = struct();
      end
      if ~isfield(sfun_display_shared, 'ud_map') || isempty(sfun_display_shared.ud_map)
          sfun_display_shared.ud_map = containers.Map('KeyType','double','ValueType','any');
      end
      key = double(block.BlockHandle);
      sfun_display_shared.ud_map(key) = ud;
  end
end

function ud = getBlockRuntimeData(block)
  try
      ud = block.UserData;
  catch
      global sfun_display_shared;
      if isempty(sfun_display_shared) || ~isstruct(sfun_display_shared) || ~isfield(sfun_display_shared, 'ud_map') || isempty(sfun_display_shared.ud_map)
          ud = struct();
          return;
      end
      key = double(block.BlockHandle);
      if isKey(sfun_display_shared.ud_map, key)
          ud = sfun_display_shared.ud_map(key);
      else
          ud = struct();
      end
  end
end
