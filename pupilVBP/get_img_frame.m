function I = get_img_frame(tlCamera)
global obj

% Check if image buffer has been filled
if (tlCamera.NumberOfQueuedFrames > 0)

    % If data processing in Matlab falls behind camera image
    % acquisition, the FIFO image frame buffer could overflow,
    % which would result in missed frames.
    if (tlCamera.NumberOfQueuedFrames > 1)
%         disp(['Data processing falling behind acquisition. ' num2str(tlCamera.NumberOfQueuedFrames) ' remains']);
    end

    % Get the pending image frame.
    imageFrame = tlCamera.GetPendingFrameOrNull;
    if ~isempty(imageFrame)
        % Get the image data as 1D uint16 array
        I = uint16(imageFrame.ImageData.ImageData_monoOrBGR);

%         disp(['Image frame number: ' num2str(imageFrame.FrameNumber)]);

        % TODO: custom image processing code goes here
        imageHeight = imageFrame.ImageData.Height_pixels;
        imageWidth = imageFrame.ImageData.Width_pixels;
        I = reshape(I, [imageWidth, imageHeight]);
%         figure(1),imagesc(I'), colormap(gray), colorbar
    end

    % Release the image frame
    delete(imageFrame);
else
    currtime = datetime('now');
    currtime.Format = 'HH:mm:s.SS';
    strcurrtime = char(currtime);
    fprintf('%s: No queued frames: %d\n', strcurrtime, tlCamera.NumberOfQueuedFrames);
    I = obj.camData;
%     I = zeros([tlCamera.ROIAndBin.ROIWidth_pixels, tlCamera.ROIAndBin.ROIHeight_pixels]);
% drawnow;

end