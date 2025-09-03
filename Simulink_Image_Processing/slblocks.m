function blkStruct = slblocks
    % This function specifies that the library 'zeromq_image_lib'
    % should be loaded and added to the Simulink Library Browser.

    % The name of the library to be displayed in the Library Browser
    blkStruct.Name = 'ZeroMQ Image Lib';

    % The name of the .slx file of the library
    blkStruct.OpenFcn = 'zeromq_image_lib';

    % The graphics to be displayed in the Library Browser's browser pane.
    % If not specified, the library icon will be used.
    blkStruct.MaskDisplay = '';

    % Information for the browser.
    Browser(1).Library = 'zeromq_image_lib';
    Browser(1).Name    = 'ZeroMQ Image Processing';
    Browser(1).IsFlat  = 0; % Is the library hierarchical?

    blkStruct.Browser = Browser;
end
