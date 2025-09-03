function sfun_zeromq_image(block)
% Level-2 MATLAB S-Function to receive images from ZeroMQ (pyzmq) and output
% as a uint8 column vector of size (H*W*C x 1).
%
% Dialog parameters (in order):
% 1) address (string) e.g. 'tcp://127.0.0.1:5555'
% 2) camera_id (string) e.g. 'Camera01'
% 3) imgHeight (int) e.g. 1024
% 4) imgWidth  (int) e.g. 1024
% 5) channels  (int) 1 or 3
% 6) timeout_ms (int) receive timeout in milliseconds (0 = blocking)
% 7) sample_time (double) sample time in seconds (-1 = inherit, >=0 = fixed)
% 8) bind_mode (bool) if true, bind to address (listen); if false, connect to address
% 9) enable_logging (bool) if true, print diagnostic logs to the console
% 10) save_debug_image (bool) if true, save the last received image to received_last.jpg
%
% Notes:
% - This implementation uses MATLAB's Python interface (py) to import pyzmq.
% - Received image bytes are written to a temporary file and read with imread.
% - Initial implementation favors compatibility and simplicity over raw speed.
% - Ensure MATLAB's pyenv points to a Python environment with pyzmq installed.

setup(block);

end

% ----------------------------------------------------------
function setup(block)
  % Register number of dialog parameters
  block.NumDialogPrms = 10;
  
  % No input ports
  block.NumInputPorts  = 0;
  block.NumOutputPorts = 1;
  
  % Check if a mask is applied. If so, read parameters from the mask.
  % Otherwise, fall back to legacy dialog parameters.
  hasMask = ~isempty(get_param(block.BlockHandle, 'MaskType'));

  if hasMask
      % Read parameters from mask
      address          = get_param(block.BlockHandle, 'address');
      camera_id        = get_param(block.BlockHandle, 'camera_id');
      imgH             = str2double(get_param(block.BlockHandle, 'imgHeight'));
      imgW             = str2double(get_param(block.BlockHandle, 'imgWidth'));
      channels_str     = get_param(block.BlockHandle, 'channels');
      if strcmp(channels_str, '3 (RGB)')
          channels = 3;
      else
          channels = 1;
      end
      timeout_ms       = str2double(get_param(block.BlockHandle, 'timeout_ms'));
      sample_time      = str2double(get_param(block.BlockHandle, 'sample_time'));
      bind_mode        = strcmp(get_param(block.BlockHandle, 'bind_mode'), 'on');
      enable_logging   = strcmp(get_param(block.BlockHandle, 'enable_logging'), 'on');
      save_debug_image = strcmp(get_param(block.BlockHandle, 'save_debug_image'), 'on');
  else
      % Fallback to legacy dialog parameters
      try
          address = char(block.DialogPrm(1).Data);
      catch
          address = 'tcp://127.0.0.1:5555';
      end
      try
          camera_id = char(block.DialogPrm(2).Data);
      catch
          camera_id = '';
      end
      try
          imgH = double(block.DialogPrm(3).Data);
      catch
          imgH = 1024;
      end
      try
          imgW = double(block.DialogPrm(4).Data);
      catch
          imgW = 1024;
      end
      try
          channels = double(block.DialogPrm(5).Data);
      catch
          channels = 3;
      end
      try
          timeout_ms = double(block.DialogPrm(6).Data);
      catch
          timeout_ms = 1000;
      end
      try
          sample_time = double(block.DialogPrm(7).Data);
      catch
          sample_time = 0.1;
      end
      try
          bind_mode = logical(block.DialogPrm(8).Data);
      catch
          bind_mode = false;
      end
      try
          enable_logging = logical(block.DialogPrm(9).Data);
      catch
          enable_logging = true;
      end
      try
          save_debug_image = logical(block.DialogPrm(10).Data);
      catch
          save_debug_image = true;
      end
  end

  % Apply sample time: -1 -> inherit, otherwise fixed sample time
  if ~isempty(sample_time) && sample_time >= 0
      block.SampleTimes = [sample_time 0];
  else
      block.SampleTimes = [-1 0];
  end
  
  % Validate basic parameters
  if isempty(address)
      error('sfun_zeromq_image: address parameter must be supplied (e.g. ''tcp://127.0.0.1:5555'')');
  end
  if ~(channels == 1 || channels == 3)
      error('sfun_zeromq_image: channels must be 1 or 3');
  end
  
  % Configure output port
  outLen = imgH * imgW * channels;
  block.OutputPort(1).Dimensions = outLen;
  block.OutputPort(1).DatatypeID = 3; % 3 = uint8 in Simulink
  block.OutputPort(1).Complexity = 'Real';
  block.OutputPort(1).SamplingMode = 'Sample';
  
  % Set block sim state compliance
  block.SimStateCompliance = 'DefaultSimState';
  
  % Register methods
  block.RegBlockMethod('Start',       @Start);
  block.RegBlockMethod('Outputs',     @Outputs);
  block.RegBlockMethod('Terminate',   @Terminate);
  
  % Save some parameters for runtime via UserData
  ud.address   = address;
  ud.camera_id = camera_id;
  ud.imgH      = imgH;
  ud.imgW      = imgW;
  ud.channels  = channels;
  ud.timeout_ms = timeout_ms;
  ud.bind_mode = bind_mode;
  ud.enable_logging = enable_logging;
  ud.save_debug_image = save_debug_image;
  ud.lastFrame = zeros(outLen,1,'uint8'); % initial blank frame
  setBlockRuntimeData(block, ud);
  
  % Log configured dialog parameters for debugging
  try
      if enable_logging
          if bind_mode
              bind_mode_str = 'true';
          else
              bind_mode_str = 'false';
          end
          fprintf('[sfun_zeromq_image] Configured params - address: %s, camera_id: %s, imgH: %d, imgW: %d, channels: %d, timeout_ms: %d, sample_time: %g, bind_mode: %s\n', ...
                  ud.address, ud.camera_id, int32(ud.imgH), int32(ud.imgW), int32(ud.channels), int32(ud.timeout_ms), sample_time, bind_mode_str);
      end
  catch
  end
end

% ----------------------------------------------------------
function Start(block)
  ud = getBlockRuntimeData(block);
  % Diagnostic logging
  try
      if isfield(ud, 'enable_logging') && ud.enable_logging
          bh = double(block.BlockHandle);
          fprintf('[sfun_zeromq_image] Start block.BlockHandle=%g\n', bh);
      end
  catch
  end
  
  % Backwards-compatibility checks
  if ~isstruct(ud)
      ud = struct();
  end
  if ~isfield(ud, 'address'),   ud.address   = 'tcp://127.0.0.1:5555'; end
  if ~isfield(ud, 'camera_id'), ud.camera_id = ''; end
  if ~isfield(ud, 'imgH'),      ud.imgH      = 1024; end
  if ~isfield(ud, 'imgW'),      ud.imgW      = 1024; end
  if ~isfield(ud, 'channels'),  ud.channels  = 3; end
  if ~isfield(ud, 'timeout_ms'),ud.timeout_ms= 1000; end
  if ~isfield(ud, 'bind_mode'), ud.bind_mode = false; end
  if ~isfield(ud, 'enable_logging'), ud.enable_logging = true; end
  if ~isfield(ud, 'save_debug_image'), ud.save_debug_image = true; end
  if ~isfield(ud, 'temp_files'),ud.temp_files= {}; end
  
  outLen = ud.imgH * ud.imgW * ud.channels;
  if ~isfield(ud, 'lastFrame') || numel(ud.lastFrame) ~= outLen
      ud.lastFrame = zeros(outLen,1,'uint8');
  end
  setBlockRuntimeData(block, ud);
  
  % Try to import pyzmq
  try
      zmq = py.importlib.import_module('zmq');
  catch ME
      project_py = 'D:\takashi\workspace\UE5PyCom\Simulink_Image_Processing\python_runtime\python.exe';
      fmt = ['Failed to import Python module ''zmq''.\n\n' ...
             'Recommended steps:\n' ...
             '  1) Run .\\Simulink_Image_Processing\\install_python_and_venv.ps1\n' ...
             '  2) Restart MATLAB and run: pyenv(''Version'', ''%s'')\n\n' ...
             'Original MATLAB error: %s'];
      errMsg = sprintf(fmt, project_py, ME.message);
      error(errMsg);
  end
  
  try
      ctx = zmq.Context();
      sock = ctx.socket(zmq.SUB);
      
      if ud.timeout_ms > 0
          sock.setsockopt(zmq.RCVTIMEO, int64(ud.timeout_ms));
      end
      
      sub_id = ud.camera_id;
      if isempty(sub_id)
          sub_id = '';
      end
      
      try
          if ud.enable_logging
              fprintf('[sfun_zeromq_image] Start subscribe using ud.camera_id="%s"\n', sub_id);
          end
      catch
      end

      try
          sock.setsockopt_string(zmq.SUBSCRIBE, sub_id);
      catch
          sock.setsockopt(zmq.SUBSCRIBE, py.bytes(sub_id, 'utf-8'));
      end
      
      if ud.bind_mode
          sock.bind(py.str(ud.address));
          if ud.enable_logging
              fprintf('[sfun_zeromq_image] Bound to %s (listening)\n', ud.address);
          end
      else
          sock.connect(py.str(ud.address));
          if ud.enable_logging
              fprintf('[sfun_zeromq_image] Connected to %s\n', ud.address);
          end
      end
      
      ud.zmq = zmq;
      ud.ctx = ctx;
      ud.sock = sock;
      ud.temp_files = {};
      
      try
          ud.poller = zmq.Poller();
          ud.poller.register(sock, zmq.POLLIN);
      catch
          ud.poller = [];
      end
      
      ud.no_data_log_interval = 1.0;
      ud.last_no_data_log_time = 0;
      
      setBlockRuntimeData(block, ud);
      
      try
          pause(0.5);
      catch
      end
      
  catch ME
      error('sfun_zeromq_image: failed to create/connect ZeroMQ socket: %s', ME.message);
  end
end

% ----------------------------------------------------------
function Outputs(block)
  ud = getBlockRuntimeData(block);
  
  if ~isfield(ud, 'sock') || isempty(ud.sock)
      block.OutputPort(1).Data = ud.lastFrame;
      return;
  end

  got_msg = false;
  msg = [];
  try
      if isfield(ud, 'poller') && ~isempty(ud.poller)
          socks = ud.poller.poll(int32(ud.timeout_ms));
          if ~isempty(socks) && int32(py.len(socks)) > 0
              msg = ud.sock.recv_multipart(ud.zmq.NOBLOCK);
              got_msg = true;
          end
      else % Fallback to blocking recv with timeout
          msg = ud.sock.recv_multipart();
          got_msg = true;
      end
  catch ME
      if ud.enable_logging
          fprintf('[sfun_zeromq_image] recv error: %s\n', ME.message);
      end
  end

  if got_msg
      numParts = int32(py.len(msg));
      if numParts >= 2
          py_img = msg{2};
          
          tmpname_base = tempname;
          imgFile = [tmpname_base '.jpg'];

          try
              py_file = py.open(imgFile, 'wb');
              py_file.write(py_img);
              py_file.close();
              
              im = imread(imgFile);

              if ud.enable_logging
                  try
                      decode_method = py.getattr(msg{1}, 'decode');
                      topic_bytes = decode_method('utf-8');
                      topic_str = char(topic_bytes);
                      img_size = size(im);
                      py_img_len = int32(py.len(py_img));
                      fprintf('[sfun_zeromq_image] T=%.4f, Received image from topic ''%s'' (%dx%dx%d, %d bytes)\n', ...
                              block.CurrentTime, topic_str, img_size(2), img_size(1), img_size(3), py_img_len);
                  catch ME_log
                      fprintf('[sfun_zeromq_image] T=%.4f, Received image (logging error: %s)\n', block.CurrentTime, ME_log.message);
                  end
              end
              
              if isfield(ud, 'save_debug_image') && ud.save_debug_image
                  try
                      savePath = fullfile(fileparts(mfilename('fullpath')), 'received_last.jpg');
                      imwrite(im, savePath);
                  catch ME_save
                      if ud.enable_logging
                          fprintf('[sfun_zeromq_image] Failed to save received image: %s\n', ME_save.message);
                      end
                  end
              end

              if ud.channels == 3 && size(im,3) == 1
                  im = repmat(im, [1 1 3]);
              elseif ud.channels == 1 && size(im,3) == 3
                  im = rgb2gray(im);
              end

              if ~isequal(size(im,1), ud.imgH) || ~isequal(size(im,2), ud.imgW)
                  im = imresize(im, [ud.imgH, ud.imgW]);
              end

              if ~isa(im, 'uint8')
                  im = im2uint8(im);
              end

              % Convert to C-style row-major order to match sfun_display_image
              % Permute from [height, width, channels] to [channels, width, height]
              im_permuted = permute(im, [3, 2, 1]);
              % Reshape to column vector.
              outData = reshape(im_permuted, [], 1);
              
              outLen = block.OutputPort(1).Dimensions;
              if numel(outData) ~= outLen
                  if numel(outData) > outLen
                      outData = outData(1:outLen);
                  else
                      outData = [outData; zeros(outLen - numel(outData), 1, 'uint8')];
                  end
              end
              
              ud.lastFrame = outData;
              block.OutputPort(1).Data = ud.lastFrame; % Output as uint8, not double
              
              try
                  delete(imgFile);
              catch
              end
              
          catch ME2
              if ud.enable_logging
                  warning('sfun_zeromq_image:decode_error', 'failed to decode image file: %s', ME2.message);
              end
              block.OutputPort(1).Data = ud.lastFrame;
          end
      else
          block.OutputPort(1).Data = ud.lastFrame;
      end
  else
      block.OutputPort(1).Data = ud.lastFrame;
  end
  
  setBlockRuntimeData(block, ud);
end

% ----------------------------------------------------------
function Terminate(block)
  ud = getBlockRuntimeData(block);
  try
      if isfield(ud, 'sock') && ~isempty(ud.sock)
          ud.sock.close();
      end
      if isfield(ud, 'ctx') && ~isempty(ud.ctx)
          ud.ctx.term();
      end
      if isfield(ud, 'enable_logging') && ud.enable_logging
          fprintf('[sfun_zeromq_image] Terminated and cleaned up ZeroMQ resources.\n');
      end
  catch ME
      if isfield(ud, 'enable_logging') && ud.enable_logging
          fprintf('[sfun_zeromq_image] Terminate encountered error: %s\n', ME.message);
      end
  end
end

% ----------------------------------------------------------
% Helpers for storing runtime data (fallback to base-workspace map if block.UserData unavailable)
function setBlockRuntimeData(block, ud)
  % Prefer block.UserData; if unavailable, store into a map in the base workspace.
  try
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_image] setBlockRuntimeData: attempting block.UserData = ud (blockHandle=%g)\n', double(block.BlockHandle));
          end
      catch
      end
      block.UserData = ud;
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              if isstruct(ud)
                  fn = fieldnames(ud);
                  fprintf('[sfun_zeromq_image] setBlockRuntimeData: stored to block.UserData; ud fields: %s\n', strjoin(fn, ', '));
              else
                  fprintf('[sfun_zeromq_image] setBlockRuntimeData: stored to block.UserData; ud is not struct\n');
              end
          end
      catch
      end
      return;
  catch
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_image] setBlockRuntimeData: block.UserData unavailable, using base-workspace map\n');
          end
      catch
      end
  end

  % Use a map stored in base workspace so it persists across simulation contexts
  try
      % ensure base map exists
      if evalin('base','exist(''sfun_zeromq_image_ud_map_base'',''var'')') ~= 1
          evalin('base','sfun_zeromq_image_ud_map_base = containers.Map(''KeyType'',''double'',''ValueType'',''any'');');
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_image] setBlockRuntimeData: created base-workspace map\n');
              end
          catch
          end
      end

      key = double(block.BlockHandle);
      % retrieve, modify, and reassign the map in base workspace
      try
          m = evalin('base','sfun_zeromq_image_ud_map_base;');
          m(key) = ud;
          assignin('base','sfun_zeromq_image_ud_map_base', m);
      catch setErr
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_image] setBlockRuntimeData: failed to set base map entry: %s\n', setErr.message);
              end
          catch
          end
      end

      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              if isstruct(ud)
                  fn = fieldnames(ud);
                  fprintf('[sfun_zeromq_image] setBlockRuntimeData: saved to base map key=%g; ud fields: %s\n', key, strjoin(fn, ', '));
              else
                  fprintf('[sfun_zeromq_image] setBlockRuntimeData: saved to base map key=%g; ud is not struct\n', key);
              end
          end
      catch
      end
      return;
  catch ME
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_image] setBlockRuntimeData: error using base map -> %s\n', ME.message);
          end
      catch
      end
  end

  % As a last resort, do nothing (ud will not persist)
  try
      if isfield(ud, 'enable_logging') && ud.enable_logging
          fprintf('[sfun_zeromq_image] setBlockRuntimeData: all persistence attempts failed\n');
      end
  catch
  end
end

function ud = getBlockRuntimeData(block)
  % Try read from block.UserData; if not available, try base-workspace map.
  ud = struct();
  try
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_image] getBlockRuntimeData: attempting to read block.UserData (blockHandle=%g)\n', double(block.BlockHandle));
          end
      catch
      end
      ud = block.UserData;
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              if isstruct(ud)
                  fn = fieldnames(ud);
                  fprintf('[sfun_zeromq_image] getBlockRuntimeData: read from block.UserData; ud fields: %s\n', strjoin(fn, ', '));
              else
                  fprintf('[sfun_zeromq_image] getBlockRuntimeData: read from block.UserData; ud is not struct\n');
              end
          end
      catch
      end
      return;
  catch
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_image] getBlockRuntimeData: block.UserData unavailable, checking base-workspace map\n');
          end
      catch
      end
  end

  try
      if evalin('base','exist(''sfun_zeromq_image_ud_map_base'',''var'')') ~= 1
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_image] getBlockRuntimeData: base map does not exist -> returning empty struct\n');
              end
          catch
          end
          ud = struct();
          return;
      end

      key = double(block.BlockHandle);
      m = evalin('base','sfun_zeromq_image_ud_map_base;');
      if isKey(m, key)
          ud = m(key);
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  if isstruct(ud)
                      fn = fieldnames(ud);
                      fprintf('[sfun_zeromq_image] getBlockRuntimeData: read from base map key=%g; ud fields: %s\n', key, strjoin(fn, ', '));
                  else
                      fprintf('[sfun_zeromq_image] getBlockRuntimeData: read from base map key=%g; ud is not struct\n', key);
                  end
              end
          catch
          end
      else
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_image] getBlockRuntimeData: no entry for key=%g in base map\n', key);
              end
          catch
          end
          ud = struct();
      end
      return;
  catch ME
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_image] getBlockRuntimeData: error while accessing base map -> %s\n', ME.message);
          end
      catch
      end
      ud = struct();
      return;
  end
end
