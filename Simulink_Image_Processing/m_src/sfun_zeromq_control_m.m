function sfun_zeromq_control_m(block)
% Level-2 MATLAB S-Function to publish camera transform commands to UE via ZeroMQ
%
% Dialog parameters:
% 1) address (string) e.g. 'tcp://127.0.0.1:5556' (default bind)
% 2) sample_time (double) e.g. 0.0625
% 3) target_id_default (string) optional default target id used when input is empty
% 4) enable_logging (bool) if true, print diagnostic logs to the console
%
% Input ports (6):
% 1) x (double)
% 2) y (double)
% 3) z (double)
% 4) pitch (double)
% 5) yaw (double)
% 6) roll (double)

setup(block);

end

function setup(block)
  block.NumDialogPrms = 4;

  block.NumInputPorts  = 6;
  block.NumOutputPorts = 0;

  for i = 1:block.NumInputPorts
      block.InputPort(i).Dimensions = 1;
      block.InputPort(i).DirectFeedthrough = true;
  end

  % Check if a mask is applied. If so, read parameters from the mask.
  % Otherwise, fall back to legacy dialog parameters.
  hasMask = ~isempty(get_param(block.BlockHandle, 'MaskType'));

  if hasMask
      % Read parameters from mask
      address           = get_param(block.BlockHandle, 'address');
      sample_time       = str2double(get_param(block.BlockHandle, 'sample_time'));
      target_id_default = get_param(block.BlockHandle, 'target_id_default');
      enable_logging    = strcmp(get_param(block.BlockHandle, 'enable_logging'), 'on');
  else
      % Fallback to legacy dialog parameters
      try
          address = char(block.DialogPrm(1).Data);
      catch
          address = 'tcp://127.0.0.1:5556';
      end
      try
          sample_time = double(block.DialogPrm(2).Data);
      catch
          sample_time = 0.0625;
      end
      try
          target_id_default = char(block.DialogPrm(3).Data);
      catch
          target_id_default = '';
      end
      try
          enable_logging = logical(block.DialogPrm(4).Data);
      catch
          enable_logging = true;
      end
  end

  if ~isempty(sample_time) && sample_time >= 0
      block.SampleTimes = [sample_time 0];
  else
      block.SampleTimes = [-1 0];
  end

  block.SimStateCompliance = 'DefaultSimState';

  block.RegBlockMethod('Start',     @Start);
  block.RegBlockMethod('Outputs',   @Outputs);
  block.RegBlockMethod('Terminate', @Terminate);

  % Save config defaults into UserData
  ud.address = address;
  ud.sample_time = sample_time;
  ud.target_id_default = target_id_default;
  ud.enable_logging = enable_logging;
  ud.pub = [];
  ud.ctx = [];
  ud.zmq = [];
  setBlockRuntimeData(block, ud);

  try
      if enable_logging
          fprintf('[sfun_zeromq_control] Configured params - address: %s, sample_time: %g, target_id_default: %s\n', ...
                  address, sample_time, target_id_default);
      end
  catch
  end
end

function Start(block)
  % Initialize or recover runtime data
  ud = getBlockRuntimeData(block);

  % Log block handle and initial ud inspection
  try
      if isfield(ud, 'enable_logging') && ud.enable_logging
          fprintf('[sfun_zeromq_control] Start: block.BlockHandle=%g\n', double(block.BlockHandle));
      end
  catch
  end
  try
      if isfield(ud, 'enable_logging') && ud.enable_logging
          if isstruct(ud)
              fn = fieldnames(ud);
              try
                  fprintf('[sfun_zeromq_control] Start: initial ud fields: %s\n', strjoin(fn, ', '));
              catch
                  fprintf('[sfun_zeromq_control] Start: initial ud has %d fields\n', numel(fn));
              end
          else
              fprintf('[sfun_zeromq_control] Start: initial ud is not struct\n');
          end
      end
  catch
  end

  % Ensure ud is a struct and has an address; fall back to dialog/defaults if needed
  try
      if ~isstruct(ud)
          ud = struct();
      end
  catch
      ud = struct();
  end

  if ~isfield(ud, 'address') || isempty(ud.address)
      try
          % Try reading from dialog parameter as a fallback
          ud.address = char(block.DialogPrm(1).Data);
      catch
          % final fallback
          ud.address = 'tcp://127.0.0.1:5556';
      end
  end

  try
      zmq = py.importlib.import_module('zmq');
  catch ME
      error('sfun_zeromq_control: Failed to import Python module ''zmq'': %s', ME.message);
  end

  try
      ctx = zmq.Context();
      pub = ctx.socket(zmq.PUB);
      % Bind to address so UE (SUB) can connect
      % Be defensive about the stored address type
      try
          bindAddr = ud.address;
          if ~ischar(bindAddr)
              try
                  bindAddr = char(bindAddr);
              catch
              end
          end
          pub.bind(py.str(bindAddr));
      catch bindErr
          error('sfun_zeromq_control: failed to bind PUB socket to "%s": %s', string(ud.address), bindErr.message);
      end

      % small pause to allow subscribers to connect
      try
          pause(0.1);
      catch
      end

      ud.zmq = zmq;
      ud.ctx = ctx;
      ud.pub = pub;
      setBlockRuntimeData(block, ud);

      % Immediately attempt to read back saved data to verify persistence
      try
          ud_check = getBlockRuntimeData(block);
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  if isstruct(ud_check)
                      fnc = fieldnames(ud_check);
                      fprintf('[sfun_zeromq_control] Start: after set/get ud fields: %s\n', strjoin(fnc, ', '));
                  else
                      fprintf('[sfun_zeromq_control] Start: after set/get ud is not struct\n');
                  end
              end
          catch
          end
      catch
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_control] Start: getBlockRuntimeData after set failed\n');
              end
          catch
          end
      end

      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] Bound PUB to %s\n', ud.address);
          end
      catch
      end
  catch ME
      error('sfun_zeromq_control: failed to create/bind PUB socket: %s', ME.message);
  end
end

function Outputs(block)
  ud = getBlockRuntimeData(block);

  % Debug: report UserData contents to help diagnose PUB availability
  try
      if isfield(ud, 'enable_logging') && ud.enable_logging
          if isstruct(ud)
              fn = fieldnames(ud);
              try
                  fprintf('[sfun_zeromq_control] Outputs invoked. ud fields: %s\n', strjoin(fn, ', '));
              catch
                  fprintf('[sfun_zeromq_control] Outputs invoked. ud has %d fields\n', numel(fn));
              end
          else
              fprintf('[sfun_zeromq_control] Outputs invoked. ud is not a struct\n');
          end
      end
  catch
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] Outputs: failed to inspect ud\n');
          end
      catch
      end
  end

  % Report whether pub appears present (best-effort) and print types
  try
      hasPub = false;
      % address content
      try
          if isfield(ud,'address')
              try
                  addrStr = char(ud.address);
              catch
                  try
                      addrStr = string(ud.address);
                  catch
                      addrStr = '<non-char address>';
                  end
              end
          else
              addrStr = '<no address field>';
          end
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_control] Outputs: ud.address=%s\n', addrStr);
              end
          catch
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_control] Outputs: ud.address (length=%d)\n', numel(addrStr));
              end
          end
      catch
      end

      if isstruct(ud) && isfield(ud, 'pub')
          try
              % isempty may error on Python objects; handle defensively
              ip = isempty(ud.pub);
              hasPub = ~ip;
          catch
              % If isempty() errors, assume pub exists but is opaque
              hasPub = true;
          end
      end

      % try to determine python type name if possible
      try
          if hasPub
              try
                  pyType = py.getattr(py.type(ud.pub), '__name__');
                  pyTypeStr = char(pyType);
              catch
                  try
                      pyTypeStr = char(py.str(py.type(ud.pub)));
                  catch
                      pyTypeStr = '<unknown>';
                  end
              end
          else
              pyTypeStr = '<no pub>';
          end
      catch
          pyTypeStr = '<type-inspect-failed>';
      end
      if isfield(ud, 'enable_logging') && ud.enable_logging
          fprintf('[sfun_zeromq_control] Outputs: hasPub=%d, pubType=%s\n', double(hasPub), pyTypeStr);
      end
  catch
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] Outputs: pub-inspection failed\n');
          end
      catch
      end
  end

  % read inputs
  try
      x = double(block.InputPort(1).Data);
  catch
      x = 0.0;
  end
  try
      y = double(block.InputPort(2).Data);
  catch
      y = 0.0;
  end
  try
      z = double(block.InputPort(3).Data);
  catch
      z = 0.0;
  end
  try
      pitch = double(block.InputPort(4).Data);
  catch
      pitch = 0.0;
  end
  try
      yaw = double(block.InputPort(5).Data);
  catch
      yaw = 0.0;
  end
  try
      roll = double(block.InputPort(6).Data);
  catch
      roll = 0.0;
  end

  % Use target_id from dialog parameter
  target_id = ud.target_id_default;
  if isempty(target_id)
      target_id = 'Camera01';
  end

  % Build message struct
  try
      msg = struct();
      msg.type = 'camera_transform';
      msg.target_id = target_id;
      msg.location = struct('x', x, 'y', y, 'z', z);
      msg.rotation = struct('pitch', pitch, 'yaw', yaw, 'roll', roll);
      % generate a uuid
      try
          uuid = char(java.util.UUID.randomUUID.toString());
      catch
          uuid = char(datestr(now,'yyyymmddHHMMSSFFF'));
      end
      msg.message_id = uuid;

      jsonStr = jsonencode(msg);

      % send via Python zmq PUB if available
      if isfield(ud, 'pub') && ~isempty(ud.pub)
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_control] T=%.4f, Sending: %s\n', block.CurrentTime, jsonStr);
              end
              ud.pub.send_string(py.str(jsonStr));
          catch ME_send
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  warning('sfun_zeromq_control:send_failed', 'send failed: %s', ME_send.message);
              end
          end
      else
          if isfield(ud, 'enable_logging') && ud.enable_logging
              warning('sfun_zeromq_control:socket_unavailable', 'PUB socket not available');
          end
      end
  catch ME
      warning('sfun_zeromq_control:prepare_failed', 'failed to prepare/send message: %s', ME.message);
  end

  % persist ud
  setBlockRuntimeData(block, ud);
end

function Terminate(block)
  ud = getBlockRuntimeData(block);
  try
      if isfield(ud, 'pub') && ~isempty(ud.pub)
          try
              ud.pub.close();
          catch
          end
      end
      if isfield(ud, 'ctx') && ~isempty(ud.ctx)
          try
              ud.ctx.term();
          catch
          end
      end
  catch ME
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] Terminate encountered error: %s\\n', ME.message);
          end
      catch
      end
  end
end

% Helpers for storing runtime data (fallback to base-workspace map if block.UserData unavailable)
function setBlockRuntimeData(block, ud)
  % Prefer block.UserData; if unavailable, store into a map in the base workspace.
  try
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] setBlockRuntimeData: attempting block.UserData = ud (blockHandle=%g)\n', double(block.BlockHandle));
          end
      catch
      end
      block.UserData = ud;
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              if isstruct(ud)
                  fn = fieldnames(ud);
                  fprintf('[sfun_zeromq_control] setBlockRuntimeData: stored to block.UserData; ud fields: %s\n', strjoin(fn, ', '));
              else
                  fprintf('[sfun_zeromq_control] setBlockRuntimeData: stored to block.UserData; ud is not struct\n');
              end
          end
      catch
      end
      return;
  catch
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] setBlockRuntimeData: block.UserData unavailable, using base-workspace map\n');
          end
      catch
      end
  end

  % Use a map stored in base workspace so it persists across simulation contexts
  try
      % ensure base map exists
      if evalin('base','exist(''sfun_zeromq_control_ud_map_base'',''var'')') ~= 1
          evalin('base','sfun_zeromq_control_ud_map_base = containers.Map(''KeyType'',''double'',''ValueType'',''any'');');
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_control] setBlockRuntimeData: created base-workspace map\n');
              end
          catch
          end
      end

      key = double(block.BlockHandle);
      % retrieve, modify, and reassign the map in base workspace
      try
          m = evalin('base','sfun_zeromq_control_ud_map_base;');
          m(key) = ud;
          assignin('base','sfun_zeromq_control_ud_map_base', m);
      catch setErr
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_control] setBlockRuntimeData: failed to set base map entry: %s\n', setErr.message);
              end
          catch
          end
      end

      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              if isstruct(ud)
                  fn = fieldnames(ud);
                  fprintf('[sfun_zeromq_control] setBlockRuntimeData: saved to base map key=%g; ud fields: %s\n', key, strjoin(fn, ', '));
              else
                  fprintf('[sfun_zeromq_control] setBlockRuntimeData: saved to base map key=%g; ud is not struct\n', key);
              end
          end
      catch
      end
      return;
  catch ME
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] setBlockRuntimeData: error using base map -> %s\n', ME.message);
          end
      catch
      end
  end

  % As a last resort, do nothing (ud will not persist)
  try
      if isfield(ud, 'enable_logging') && ud.enable_logging
          fprintf('[sfun_zeromq_control] setBlockRuntimeData: all persistence attempts failed\n');
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
              fprintf('[sfun_zeromq_control] getBlockRuntimeData: attempting to read block.UserData (blockHandle=%g)\n', double(block.BlockHandle));
          end
      catch
      end
      ud = block.UserData;
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              if isstruct(ud)
                  fn = fieldnames(ud);
                  fprintf('[sfun_zeromq_control] getBlockRuntimeData: read from block.UserData; ud fields: %s\n', strjoin(fn, ', '));
              else
                  fprintf('[sfun_zeromq_control] getBlockRuntimeData: read from block.UserData; ud is not struct\n');
              end
          end
      catch
      end
      return;
  catch
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] getBlockRuntimeData: block.UserData unavailable, checking base-workspace map\n');
          end
      catch
      end
  end

  try
      if evalin('base','exist(''sfun_zeromq_control_ud_map_base'',''var'')') ~= 1
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_control] getBlockRuntimeData: base map does not exist -> returning empty struct\n');
              end
          catch
          end
          ud = struct();
          return;
      end

      key = double(block.BlockHandle);
      m = evalin('base','sfun_zeromq_control_ud_map_base;');
      if isKey(m, key)
          ud = m(key);
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  if isstruct(ud)
                      fn = fieldnames(ud);
                      fprintf('[sfun_zeromq_control] getBlockRuntimeData: read from base map key=%g; ud fields: %s\n', key, strjoin(fn, ', '));
                  else
                      fprintf('[sfun_zeromq_control] getBlockRuntimeData: read from base map key=%g; ud is not struct\n', key);
                  end
              end
          catch
          end
      else
          try
              if isfield(ud, 'enable_logging') && ud.enable_logging
                  fprintf('[sfun_zeromq_control] getBlockRuntimeData: no entry for key=%g in base map\n', key);
              end
          catch
          end
          ud = struct();
      end
      return;
  catch ME
      try
          if isfield(ud, 'enable_logging') && ud.enable_logging
              fprintf('[sfun_zeromq_control] getBlockRuntimeData: error while accessing base map -> %s\n', ME.message);
          end
      catch
      end
      ud = struct();
      return;
  end
end
