function run_image_processing_test()
% run_image_processing_test - Tests the MATLAB image processing library.
%
% This script demonstrates how to use the created classes:
% - ZMQ.ZeroMQImageReceiver
% - ZMQ.ZeroMQControlSender
% - Features.ImageFeatureExtractor
% - Utils.ImageDisplayer
%
% Prerequisites:
% - A ZeroMQ PUB socket must be sending images on 'tcp://localhost:5555'
%   with the topic 'Camera01'. The 'test_ue5_image_sender.py' script can be
%   used for this.
% - The MEX files must be compiled by running 'build_mex_files.m'.

% --- Configuration ---
IMG_H = 1024;
IMG_W = 1024;
CHANNELS = 3;
ZMQ_RX_ADDRESS = 'tcp://localhost:5555';
ZMQ_RX_TOPIC = 'Camera01';
ZMQ_TX_ADDRESS = 'tcp://*:5556';

% --- Add paths ---
addpath(fullfile(pwd, 'mex'));

% --- Initialization ---
fprintf('Initializing components...\n');
try
    % Create a control sender
    sender = ZMQ.ZeroMQControlSender(ZMQ_TX_ADDRESS);
    
    % Create an image receiver
    receiver = ZMQ.ZeroMQImageReceiver(ZMQ_RX_ADDRESS, ZMQ_RX_TOPIC, ...
        'ImageHeight', IMG_H, 'ImageWidth', IMG_W, 'Channels', CHANNELS);
        
    % Create feature extractors for both modes
    orbExtractor = Features.ImageFeatureExtractor('ORB', 'MaxFeatures', 500);
    centroidExtractor = Features.ImageFeatureExtractor('Centroid', 'Threshold', 100);
    
    % Create display windows
    originalDisplay = Utils.ImageDisplayer(IMG_H, IMG_W, CHANNELS, 'Title', 'Original Image');
    orbDisplay = Utils.ImageDisplayer(IMG_H, IMG_W, CHANNELS, 'Title', 'ORB Features');
    centroidDisplay = Utils.ImageDisplayer(IMG_H, IMG_W, CHANNELS, 'Title', 'Centroids');
    
catch ME
    fprintf('Error during initialization: %s\n', ME.message);
    return;
end

fprintf('Initialization complete. Starting processing loop...\n');
fprintf('Press Ctrl+C to stop.\n');

% --- Processing Loop ---
tic;
frameCount = 0;
while true
    try
        % Send a dummy control command (e.g., oscillating position)
        t = toc;
        loc = [1000*sin(t), 1000*cos(t), 50];
        rot = [0, 0, 90*sin(t*0.5)];
        sender.sendTransform('Camera01', loc, rot);
        
        % Receive an image
        img = receiver.receive();
        
        if ~isempty(img)
            frameCount = frameCount + 1;
            
            % Display original image
            originalDisplay.update(img);
            
            % Process and display ORB features
            [orbImg, orbFeatures] = orbExtractor.extract(img);
            orbDisplay.update(orbImg);
            
            % Process and display centroids
            [centroidImg, centroidFeatures] = centroidExtractor.extract(img);
            centroidDisplay.update(centroidImg);
            
            if mod(frameCount, 30) == 0
                fprintf('Processed %d frames. FPS: %.2f\n', frameCount, frameCount / toc);
            end
        end
        
        % Pause briefly to allow other processes to run
        pause(0.01);
        
    catch ME
        fprintf('Error in processing loop: %s\n', ME.message);
        break;
    end
end

% --- Cleanup ---
fprintf('Cleaning up...\n');
clear sender receiver orbExtractor centroidExtractor originalDisplay orbDisplay centroidDisplay;
fprintf('Test finished.\n');

end
