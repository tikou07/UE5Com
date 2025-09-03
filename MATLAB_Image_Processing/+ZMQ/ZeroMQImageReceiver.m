classdef ZeroMQImageReceiver < handle
    % ZeroMQImageReceiver - Receives images via a ZeroMQ SUB socket.
    %
    % This class wraps a MEX function to provide a high-level interface
    % for receiving image data sent over a ZeroMQ SUB/PUB socket.
    %
    % Methods:
    %   ZeroMQImageReceiver(address, topic, options) - Constructor
    %   receive() - Receives an image frame.
    %   delete() - Destructor to clean up ZeroMQ resources.

    properties (Access = private)
        isInitialized = false;
        imgHeight
        imgWidth
        channels
    end

    methods
        function obj = ZeroMQImageReceiver(address, topic, varargin)
            % Constructor for ZeroMQImageReceiver.
            %
            % Inputs:
            %   address - ZMQ socket address (e.g., 'tcp://localhost:5555').
            %   topic   - The subscription topic (e.g., 'Camera01').
            %
            % Optional Name-Value Pair Arguments:
            %   'BindMode'  - true to bind, false to connect (default: false).
            %   'Timeout'   - Receive timeout in milliseconds (default: 100).
            %   'ImageHeight' - Expected image height (default: 1024).
            %   'ImageWidth'  - Expected image width (default: 1024).
            %   'Channels'    - Expected number of channels (default: 3).

            p = inputParser;
            addRequired(p, 'address', @ischar);
            addRequired(p, 'topic', @ischar);
            addParameter(p, 'BindMode', false, @islogical);
            addParameter(p, 'Timeout', 100, @isnumeric);
            addParameter(p, 'ImageHeight', 1024, @isnumeric);
            addParameter(p, 'ImageWidth', 1024, @isnumeric);
            addParameter(p, 'Channels', 3, @isnumeric);
            parse(p, address, topic, varargin{:});

            obj.imgHeight = p.Results.ImageHeight;
            obj.imgWidth = p.Results.ImageWidth;
            obj.channels = p.Results.Channels;

            try
                % Call MEX function to initialize
                mex_zeromq_handler('image_init', ...
                    p.Results.address, ...
                    p.Results.topic, ...
                    p.Results.BindMode, ...
                    p.Results.Timeout, ...
                    obj.imgHeight, ...
                    obj.imgWidth, ...
                    obj.channels);
                obj.isInitialized = true;
            catch ME
                warning(ME.identifier, 'Failed to initialize ZeroMQ receiver: %s', ME.message);
                rethrow(ME);
            end
        end

        function imageData = receive(obj)
            % receive - Receives an image frame from the socket.
            %
            % Output:
            %   imageData - An [H x W x C] uint8 image matrix, or empty
            %               if no new data is received.

            imageData = [];
            if ~obj.isInitialized
                warning('Receiver is not initialized.');
                return;
            end

            try
                % Call MEX function to receive data
                raw_vector = mex_zeromq_handler('image_receive');
                
                % Reshape the received vector into an image
                if ~isempty(raw_vector)
                    % Reshape from C-style [C, W, H] stream to MATLAB's [H, W, C]
                    im_reshaped = reshape(raw_vector, [obj.channels, obj.imgWidth, obj.imgHeight]);
                    imageData = permute(im_reshaped, [3, 2, 1]);
                end
            catch ME
                warning(ME.identifier, 'Error receiving data: %s', ME.message);
            end
        end

        function delete(obj)
            % delete - Destructor to terminate the ZeroMQ connection.
            % The cleanup is handled globally by the MEX function's exit hook.
            % We can call terminate explicitly if needed, but it's not strictly
            % necessary if the object is cleared at the end of a script.
            if obj.isInitialized
                try
                    % The handler manages global state, so terminate might not be
                    % ideal if the control sender is still in use.
                    % For simplicity, we'll let the mexAtExit cleanup handle it.
                    % mex_zeromq_handler('terminate');
                    obj.isInitialized = false;
                catch ME
                    warning(ME.identifier, 'Error during ZeroMQ receiver cleanup: %s', ME.message);
                end
            end
        end
    end
end
