classdef ImageFeatureExtractor < handle
    % ImageFeatureExtractor - Extracts features from images.
    %
    % Supports two modes:
    % 1) 'ORB': Detects ORB keypoints using OpenCV in Python.
    % 2) 'Centroid': Performs binarization and finds centroids of connected components.

    properties (Access = private)
        processingMode
        orbDetector
        maxFeatures
        threshold
        cv2
        np
    end

    methods
        function obj = ImageFeatureExtractor(mode, varargin)
            % Constructor for ImageFeatureExtractor.
            %
            % Inputs:
            %   mode - 'ORB' or 'Centroid'.
            %
            % Optional Name-Value Pair Arguments:
            %   'MaxFeatures' - For 'ORB' mode (default: 500).
            %   'Threshold'   - For 'Centroid' mode (default: 127).

            p = inputParser;
            addRequired(p, 'mode', @(x) ischar(x) && (strcmpi(x, 'ORB') || strcmpi(x, 'Centroid')));
            addParameter(p, 'MaxFeatures', 500, @isnumeric);
            addParameter(p, 'Threshold', 127, @isnumeric);
            parse(p, mode, varargin{:});

            obj.processingMode = lower(p.Results.mode);
            obj.maxFeatures = p.Results.MaxFeatures;
            obj.threshold = p.Results.Threshold;

            % Initialize Python modules
            try
                obj.cv2 = py.importlib.import_module('cv2');
                obj.np = py.importlib.import_module('numpy');
            catch ME
                error('Failed to import Python modules (cv2, numpy). Ensure they are installed. Error: %s', ME.message);
            end

            if strcmp(obj.processingMode, 'orb')
                obj.orbDetector = obj.cv2.ORB_create(py.int(obj.maxFeatures));
            end
        end

        function [processedImage, features] = extract(obj, image)
            % extract - Processes an image to extract features.
            %
            % Input:
            %   image - An [H x W x C] uint8 image matrix.
            %
            % Outputs:
            %   processedImage - The image with features drawn on it.
            %   features       - A matrix of feature data.
            
            if ~isa(image, 'uint8')
                error('Input image must be of type uint8.');
            end

            if strcmp(obj.processingMode, 'orb')
                [processedImage, features] = obj.extractORB(image);
            else % 'centroid'
                [processedImage, features] = obj.extractCentroids(image);
            end
        end
    end

    methods (Access = private)
        function [imgOut, features] = extractORB(obj, imgIn)
            py_img_in = py.numpy.array(imgIn);
            py_gray = obj.cv2.cvtColor(py_img_in, obj.cv2.COLOR_RGB2GRAY);
            
            kp = obj.orbDetector.detect(py_gray, py.None);
            py_img_out = obj.cv2.drawKeypoints(py_img_in, kp, py.None, py.tuple({py.int(255), py.int(0), py.int(0)}));
            
            imgOut = uint8(py_img_out);
            
            num_features = length(kp);
            if num_features > 0
                features = zeros(num_features, 3);
                for i = 1:num_features
                    keypoint = kp{i};
                    pt = double(py.getattr(keypoint, 'pt'));
                    response = double(py.getattr(keypoint, 'response'));
                    features(i, :) = [pt(1), pt(2), response];
                end
            else
                features = zeros(0, 3);
            end
        end

        function [imgOut, features] = extractCentroids(obj, imgIn)
            % Convert to Python numpy array
            py_img_in = py.numpy.array(imgIn);
            
            % Convert to grayscale
            if py_img_in.ndim == 3
                py_gray = obj.cv2.cvtColor(py_img_in, obj.cv2.COLOR_RGB2GRAY);
            else
                py_gray = py_img_in;
            end

            % Binarize the image using the threshold
            py_thresh = obj.cv2.threshold(py_gray, py.int(obj.threshold), py.int(255), obj.cv2.THRESH_BINARY);
            py_binary_matrix = py_thresh{2};

            % Find contours
            contours = obj.cv2.findContours(py_binary_matrix, obj.cv2.RETR_EXTERNAL, obj.cv2.CHAIN_APPROX_SIMPLE);
            py_contours = contours{1}; % In OpenCV 4+, findContours returns (image, contours, hierarchy)

            % Calculate centroids from moments
            num_contours = length(py_contours);
            if num_contours > 0
                features = zeros(num_contours, 2);
                for i = 1:num_contours
                    M = obj.cv2.moments(py_contours{i});
                    m00 = M{'m00'};
                    if m00 > 0
                        cx = M{'m10'} / m00;
                        cy = M{'m01'} / m00;
                        features(i, :) = [double(cx), double(cy)];
                    end
                end
            else
                features = zeros(0, 2);
            end

            % Create visualization
            binary_matrix = uint8(py_binary_matrix);
            imgOut = repmat(binary_matrix, [1, 1, 3]);
            if ~isempty(features)
                % Draw markers manually
                for i = 1:size(features, 1)
                    cx = round(features(i, 1));
                    cy = round(features(i, 2));
                    
                    markerSize = 2;
                    if cx > markerSize && cx <= size(imgOut, 2) - markerSize && cy > markerSize && cy <= size(imgOut, 1) - markerSize
                        imgOut(cy-markerSize:cy+markerSize, cx, 2) = 255; % Green
                        imgOut(cy, cx-markerSize:cx+markerSize, 2) = 255; % Green
                        imgOut(cy-markerSize:cy+markerSize, cx, [1,3]) = 0; % Black out Red/Blue
                        imgOut(cy, cx-markerSize:cx+markerSize, [1,3]) = 0; % Black out Red/Blue
                    end
                end
            end
        end

        % The simpleConnectedComponents method is no longer needed as centroid
        % detection is now handled by Python's OpenCV.
        % It is kept here for reference but is not used.
        function [labeled, num_labels] = simpleConnectedComponents(~, binary_img)
            labeled = zeros(size(binary_img));
            num_labels = 0;
            warning('simpleConnectedComponents is deprecated and should not be used due to performance issues.');
        end
    end
end
