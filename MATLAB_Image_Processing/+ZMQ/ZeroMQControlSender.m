classdef ZeroMQControlSender < handle
    % ZeroMQControlSender - Sends control commands via a ZeroMQ PUB socket.
    %
    % Wraps a MEX function to provide a high-level interface for sending
    % control data (e.g., actor transforms) as JSON over a ZeroMQ PUB socket.
    %
    % Methods:
    %   ZeroMQControlSender(address) - Constructor
    %   sendTransform(target_id, location, rotation) - Sends a transform command.
    %   delete() - Destructor to clean up ZeroMQ resources.

    properties (Access = private)
        isInitialized = false;
    end

    methods
        function obj = ZeroMQControlSender(address)
            % Constructor for ZeroMQControlSender.
            %
            % Input:
            %   address - ZMQ socket address to bind to (e.g., 'tcp://*:5556').

            if nargin < 1
                error('Address argument is required.');
            end

            try
                % Call MEX function to initialize
                mex_zeromq_handler('control_init', address);
                obj.isInitialized = true;
            catch ME
                warning(ME.identifier, 'Failed to initialize ZeroMQ sender: %s', ME.message);
                rethrow(ME);
            end
        end

        function sendTransform(obj, target_id, location, rotation)
            % sendTransform - Sends an actor transform command.
            %
            % Inputs:
            %   target_id - String identifier for the target actor.
            %   location  - A 3-element vector [x, y, z].
            %   rotation  - A 3-element vector [roll, pitch, yaw].

            if ~obj.isInitialized
                warning('Sender is not initialized.');
                return;
            end
            
            if ~ischar(target_id) || ~isnumeric(location) || numel(location) ~= 3 || ~isnumeric(rotation) || numel(rotation) ~= 3
                error('Invalid input arguments. Check types and dimensions.');
            end

            try
                % Call MEX function to send data
                mex_zeromq_handler('control_send', ...
                    target_id, ...
                    location(1), location(2), location(3), ...
                    rotation(1), rotation(2), rotation(3));
            catch ME
                warning(ME.identifier, 'Error sending transform data: %s', ME.message);
            end
        end

        function delete(obj)
            % delete - Destructor to terminate the ZeroMQ connection.
            if obj.isInitialized
                try
                    % The handler manages global state, so we don't necessarily
                    % need to call terminate here. The mexAtExit hook will clean up.
                    % mex_zeromq_handler('terminate');
                    obj.isInitialized = false;
                catch ME
                    warning(ME.identifier, 'Error during ZeroMQ sender cleanup: %s', ME.message);
                end
            end
        end
    end
end
