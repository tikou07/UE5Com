function sfun_image_feature_extraction_m(block)
% Level-2 MATLAB S-Function to perform image processing on an input
% image signal using Python (OpenCV).
%
% Processing modes:
% 1) ORB Features: Extract ORB feature points and draw them on the image
% 2) Binarization & Centroids: Binarize image and calculate region centroids
%
% This S-Function uses a map in the base workspace to store runtime data
% to ensure stability and avoid Simulink API limitations.

setup(block);

end

% ----------------------------------------------------------
function setup(block)
  % Register number of dialog parameters
  block.NumDialogPrms = 8;
  
  % Register number of ports
  block.NumInputPorts  = 1;
  block.NumOutputPorts = 2;
  
  % Configure Input Port 1
  block.InputPort(1).DatatypeID = 3; % uint8
  block.InputPort(1).Complexity = 'Real';
  block.InputPort(1).DirectFeedthrough = true;

  % Configure Output Port 1
  block.OutputPort(1).DimensionsMode = 'Fixed';
  block.OutputPort(1).DatatypeID = 3; % uint8
  block.OutputPort(1).Complexity = 'Real';
  
  % Configure Output Port 2 (Feature Data)
  block.OutputPort(2).DimensionsMode = 'Variable';
  block.OutputPort(2).DatatypeID = 0; % double
  block.OutputPort(2).Complexity = 'Real';

  % Set sample time
  block.SampleTimes = [block.DialogPrm(5).Data 0];
  
  % Set block sim state compliance
  block.SimStateCompliance = 'DefaultSimState';
  
  % Fix all port dimensions from dialog parameters (make them explicit/fixed)
  imgH = block.DialogPrm(1).Data;
  imgW = block.DialogPrm(2).Data;
  channels = block.DialogPrm(3).Data;
  nfeatures = block.DialogPrm(4).Data;
  
  % Set input port dimensions
  inDim = imgH * imgW * channels;
  block.InputPort(1).DimensionsMode = 'Fixed';
  block.InputPort(1).Dimensions = inDim;
  
  % Set output port 1 dimensions (same as input)
  block.OutputPort(1).DimensionsMode = 'Fixed';
  block.OutputPort(1).Dimensions = inDim;
  
  % Set output port 2 dimensions (variable with upper bound)
  block.OutputPort(2).DimensionsMode = 'Variable';
  block.OutputPort(2).Dimensions = [nfeatures, 3];
  
  % Register methods (no dimension callbacks needed)
  block.RegBlockMethod('Start', @Start);
  block.RegBlockMethod('Outputs', @Outputs);
  block.RegBlockMethod('Terminate', @Terminate);
  
end

% ----------------------------------------------------------
function Start(block)
  ud.enable_logging = block.DialogPrm(6).Data;
  ud.processing_mode = block.DialogPrm(7).Data;
  ud.threshold = block.DialogPrm(8).Data;
  nfeatures = block.DialogPrm(4).Data;
  
  try
      if ud.enable_logging
          fprintf('[sfun_image_feature_extraction] Importing Python modules...\n');
      end
      ud.cv2 = py.importlib.import_module('cv2');
      ud.np = py.importlib.import_module('numpy');
  catch ME
      error('Failed to import Python modules (cv2, numpy). Error: %s', ME.message);
  end
  
  % Initialize ORB detector only if ORB mode is selected
  if ud.processing_mode == 1  % ORB Features mode
      try
          if ud.enable_logging
              fprintf('[sfun_image_feature_extraction] Creating ORB detector...\n');
          end
          ud.orb = ud.cv2.ORB_create(py.int(nfeatures));
      catch ME
          error('Failed to create ORB detector: %s', ME.message);
      end
  else  % Binarization & Centroids mode
      if ud.enable_logging
          fprintf('[sfun_image_feature_extraction] Initialized for binarization and centroid detection...\n');
      end
  end
  
  setBlockRuntimeData(block, ud);
end

% ----------------------------------------------------------
function Outputs(block)
  ud = getBlockRuntimeData(block);
  
  imgH = block.DialogPrm(1).Data;
  imgW = block.DialogPrm(2).Data;
  channels = block.DialogPrm(3).Data;
  input_vector = block.InputPort(1).Data;
  
  try
    % Convert from row-major order (same as sfun_zeromq_image_m.m)
    % First reshape to [channels, width, height], then permute to [height, width, channels]
    img_temp = reshape(input_vector, [channels, imgW, imgH]);
    img_in = permute(img_temp, [3, 2, 1]);  % [height, width, channels]
    py_img_in = py.numpy.array(img_in);
    py_gray = ud.cv2.cvtColor(py_img_in, ud.cv2.COLOR_RGB2GRAY);
    
    if ud.processing_mode == 1  % ORB Features mode
        % Existing ORB feature extraction
        kp = ud.orb.detect(py_gray, py.None);
        py_img_out = ud.cv2.drawKeypoints(py_img_in, kp, py.None, py.tuple({py.int(255), py.int(0), py.int(0)}), ud.cv2.DrawMatchesFlags_DEFAULT);
        
        img_out_matrix = uint8(py_img_out);
        % Convert back to row-major order for output
        img_out_permuted = permute(img_out_matrix, [3, 2, 1]);
        output_image_vector = reshape(img_out_permuted, [], 1);
        
        num_features = length(kp);
        if num_features > 0
            feature_data = zeros(num_features, 3);
            for i = 1:num_features
                keypoint = kp{i};
                pt = double(py.getattr(keypoint, 'pt'));
                response = double(py.getattr(keypoint, 'response'));
                feature_data(i, 1) = pt(1);
                feature_data(i, 2) = pt(2);
                feature_data(i, 3) = response;
            end
        else
            feature_data = zeros(0, 3);
        end
        
    else  % Binarization & Centroids mode
        % Use basic MATLAB functions to avoid toolbox dependencies
        try
            % Convert Python array to MATLAB
            gray_matrix = uint8(py_gray);
            
            % Apply threshold using MATLAB
            binary_matrix = gray_matrix > ud.threshold;
            
            % Connected component analysis using basic MATLAB functions
            labeled_matrix = simpleConnectedComponents(binary_matrix);
            max_label = max(labeled_matrix(:));
            
            if max_label > 0
                feature_data = zeros(max_label, 2);
                
                for label = 1:max_label
                    % Find pixels belonging to this component
                    [rows, cols] = find(labeled_matrix == label);
                    
                    if ~isempty(rows)
                        % Calculate centroid for this component
                        cx = mean(cols);
                        cy = mean(rows);
                        feature_data(label, 1) = cx;
                        feature_data(label, 2) = cy;
                        
                        if ud.enable_logging
                            fprintf('[sfun_image_feature_extraction] Object %d centroid at (%.1f, %.1f)\n', label, cx, cy);
                        end
                    end
                end
            else
                feature_data = zeros(0, 2);
            end
            
            % Create visualization image
            % Convert binary to 3-channel for visualization
            binary_3ch = repmat(uint8(binary_matrix) * 255, [1, 1, 3]);
            
            % Draw all centroids as green crosses
            for i = 1:size(feature_data, 1)
                cx = round(feature_data(i, 1));
                cy = round(feature_data(i, 2));
                
                % Draw a simple cross pattern for centroid visualization
                if cx > 5 && cx <= size(binary_3ch, 2) - 5 && cy > 5 && cy <= size(binary_3ch, 1) - 5
                    % Draw green cross
                    binary_3ch(cy-2:cy+2, cx, 2) = 255;  % Green channel
                    binary_3ch(cy, cx-2:cx+2, 2) = 255;  % Green channel
                    binary_3ch(cy-2:cy+2, cx, [1,3]) = 0;  % Remove red and blue
                    binary_3ch(cy, cx-2:cx+2, [1,3]) = 0;  % Remove red and blue
                end
            end
            
            % Convert back to row-major order for output
            binary_3ch_permuted = permute(binary_3ch, [3, 2, 1]);
            output_image_vector = reshape(binary_3ch_permuted, [], 1);
            
        catch ME_inner
            if ud.enable_logging
                fprintf('[sfun_image_feature_extraction] Binarization error: %s\n', ME_inner.message);
            end
            % Fallback: return original image
            img_out_matrix = uint8(py_img_in);
            % Convert back to row-major order for output
            img_out_permuted = permute(img_out_matrix, [3, 2, 1]);
            output_image_vector = reshape(img_out_permuted, [], 1);
            feature_data = zeros(0, 2);
        end
    end
    
    block.OutputPort(1).Data = output_image_vector;
    block.OutputPort(2).CurrentDimensions = size(feature_data);
    block.OutputPort(2).Data = feature_data;

  catch ME
    if isfield(ud, 'enable_logging') && ud.enable_logging
        fprintf('[sfun_image_feature_extraction] Error in Outputs: %s\n', ME.message);
    end
    block.OutputPort(1).Data = zeros(imgH * imgW * channels, 1, 'uint8');
    if ud.processing_mode == 1
        block.OutputPort(2).CurrentDimensions = [0, 3];
        block.OutputPort(2).Data = zeros(0, 3);
    else
        block.OutputPort(2).CurrentDimensions = [0, 2];
        block.OutputPort(2).Data = zeros(0, 2);
    end
  end
end

% ----------------------------------------------------------
function Terminate(block)
  clearBlockRuntimeData(block);
end

% ----------------------------------------------------------
% Helper functions for robust state management using a base workspace map
% ----------------------------------------------------------
function setBlockRuntimeData(block, data)
  map_name = 'sfun_feature_extraction_map';
  if evalin('base', sprintf('exist(''%s'',''var'')', map_name)) ~= 1
    evalin('base', sprintf('%s = containers.Map(''KeyType'', ''char'', ''ValueType'', ''any'');', map_name));
  end
  
  map = evalin('base', map_name);
  key = getfullname(block.BlockHandle);
  map(key) = data;
  assignin('base', map_name, map);
end

function data = getBlockRuntimeData(block)
  map_name = 'sfun_feature_extraction_map';
  data = struct();
  if evalin('base', sprintf('exist(''%s'',''var'')', map_name)) == 1
    map = evalin('base', map_name);
    key = getfullname(block.BlockHandle);
    if isKey(map, key)
      data = map(key);
    end
  end
end

function clearBlockRuntimeData(block)
    map_name = 'sfun_feature_extraction_map';
    if evalin('base', sprintf('exist(''%s'',''var'')', map_name)) == 1
        map = evalin('base', map_name);
        key = getfullname(block.BlockHandle);
        if isKey(map, key)
            remove(map, key);
            assignin('base', map_name, map);
        end
    end
end

% ----------------------------------------------------------
% Simple connected components analysis using basic MATLAB functions
% ----------------------------------------------------------
function labeled = simpleConnectedComponents(binary_img)
    % Simple 4-connected component labeling algorithm
    [height, width] = size(binary_img);
    labeled = zeros(height, width);
    current_label = 0;
    
    % 4-connected neighbors (up, down, left, right)
    neighbors = [-1, 0; 1, 0; 0, -1; 0, 1];
    
    for y = 1:height
        for x = 1:width
            if binary_img(y, x) && labeled(y, x) == 0
                % Start new component
                current_label = current_label + 1;
                
                % Flood fill using stack-based approach
                stack = [y, x];
                
                while ~isempty(stack)
                    % Pop from stack
                    current_y = stack(end, 1);
                    current_x = stack(end, 2);
                    stack(end, :) = [];
                    
                    % Skip if already labeled
                    if labeled(current_y, current_x) ~= 0
                        continue;
                    end
                    
                    % Label current pixel
                    labeled(current_y, current_x) = current_label;
                    
                    % Check 4-connected neighbors
                    for i = 1:size(neighbors, 1)
                        ny = current_y + neighbors(i, 1);
                        nx = current_x + neighbors(i, 2);
                        
                        % Check bounds and conditions
                        if ny >= 1 && ny <= height && nx >= 1 && nx <= width
                            if binary_img(ny, nx) && labeled(ny, nx) == 0
                                % Add to stack
                                stack = [stack; ny, nx];
                            end
                        end
                    end
                end
            end
        end
    end
end
