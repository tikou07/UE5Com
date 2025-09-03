classdef ImageDisplayer < handle
    % ImageDisplayer - A class to display images in a MATLAB figure.
    %
    % This class provides a simple interface to display images in a figure
    % window, similar to the functionality of sfun_display_image. It is
    % designed to be used in MATLAB scripts and functions without a
    % Simulink environment.
    %
    % Properties:
    %   figHandle - Handle to the figure window.
    %   imgHandle - Handle to the image object.
    %   axHandle  - Handle to the axes object.
    %   imgHeight - Height of the image.
    %   imgWidth  - Width of the image.
    %   channels  - Number of color channels (1 for grayscale, 3 for RGB).
    %
    % Methods:
    %   ImageDisplayer(height, width, channels, varargin) - Constructor
    %   update(imageData) - Updates the displayed image.
    %   delete() - Closes the figure window when the object is destroyed.

    properties (Access = private)
        figHandle
        imgHandle
        axHandle
        imgHeight
        imgWidth
        channels
        lastImage
    end

    methods
        function obj = ImageDisplayer(height, width, channels, varargin)
            % Constructor for the ImageDisplayer class.
            %
            % Inputs:
            %   height   - Image height in pixels.
            %   width    - Image width in pixels.
            %   channels - Number of channels (1 or 3).
            %
            % Optional Name-Value Pair Arguments:
            %   'Title' - A string for the figure window title.

            p = inputParser;
            addRequired(p, 'height', @isnumeric);
            addRequired(p, 'width', @isnumeric);
            addRequired(p, 'channels', @(x) isnumeric(x) && (x==1 || x==3));
            addParameter(p, 'Title', 'Image Display', @ischar);
            parse(p, height, width, channels, varargin{:});

            obj.imgHeight = p.Results.height;
            obj.imgWidth = p.Results.width;
            obj.channels = p.Results.channels;
            figTitle = p.Results.Title;

            % Create an initial blank image
            if obj.channels == 1
                obj.lastImage = zeros(obj.imgHeight, obj.imgWidth, 'uint8');
            else
                obj.lastImage = zeros(obj.imgHeight, obj.imgWidth, obj.channels, 'uint8');
            end

            % Create the figure and image display
            obj.figHandle = figure('Name', figTitle, 'NumberTitle', 'off', 'Visible', 'on');
            obj.axHandle = axes('Parent', obj.figHandle);
            
            if obj.channels == 1
                obj.imgHandle = image(obj.lastImage, 'Parent', obj.axHandle);
                colormap(obj.axHandle, gray(256));
            else
                obj.imgHandle = image(obj.lastImage, 'Parent', obj.axHandle);
            end
            axis(obj.axHandle, 'image', 'off');
            drawnow;
        end

        function update(obj, imageData)
            % update - Updates the displayed image.
            %
            % Input:
            %   imageData - A vector (H*W*C x 1) or a matrix (H x W x C)
            %               of type uint8.

            if isempty(imageData)
                return;
            end

            try
                imageData = uint8(imageData);
            catch
                warning('ImageDisplayer: Could not cast imageData to uint8.');
                return;
            end

            % Reshape if the input is a vector
            expectedLen = obj.imgHeight * obj.imgWidth * obj.channels;
            if isvector(imageData)
                if numel(imageData) ~= expectedLen
                    warning('ImageDisplayer: Input vector size does not match expected dimensions.');
                    % Attempt to resize
                    if numel(imageData) > expectedLen
                        imageData = imageData(1:expectedLen);
                    else
                        imageData = [imageData(:); zeros(expectedLen - numel(imageData), 1, 'uint8')];
                    end
                end
                % Reshape from C-style [C, W, H] stream to MATLAB's [H, W, C]
                im_reshaped = reshape(imageData, [obj.channels, obj.imgWidth, obj.imgHeight]);
                im = permute(im_reshaped, [3, 2, 1]);
            else
                % Assume it's already in [H, W, C] format
                im = imageData;
            end

            % Update the image data
            if ishandle(obj.imgHandle)
                set(obj.imgHandle, 'CData', im);
                drawnow('limitrate');
                obj.lastImage = im;
            end
        end

        function delete(obj)
            % delete - Destructor to close the figure window.
            if ishandle(obj.figHandle)
                close(obj.figHandle);
            end
        end
    end
end
