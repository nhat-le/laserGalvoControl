%New version reads from an Arduino instead of NIDAQ

close all; clc;

% DEFAULT PARAMETERS =============================
% Dur = 1800;
% PROOT = 'C:\data\Vincent\Pupil\Pupil - Sound\CtlAmp\G133\';
% FNSave = 'G133_6diffFreq1';
% TH = 0.8;
Dur = 1800;
TH = 2.55;

usecam = 1;

if usecam
    NET.addAssembly('C:\Users\SurlabWF2P\Downloads\Scientific_Camera_Interfaces_Windows-1.4\Scientific Camera Interfaces\SDK\DotNet Toolkit\dlls\Managed_64_lib\Thorlabs.TSI.TLCamera.dll');
    disp('Dot NET assembly loaded.');

    tlCameraSDK = Thorlabs.TSI.TLCamera.TLCameraSDK.OpenTLCameraSDK;

    % Get serial numbers of connected TLCameras.
    serialNumbers = tlCameraSDK.DiscoverAvailableCameras;
    disp([num2str(serialNumbers.Count), ' camera was discovered.']);
    
    % Open the first TLCamera using the serial number.
    disp('Opening the first camera')
    tlCamera = tlCameraSDK.OpenCamera(serialNumbers.Item(0), false);
    
    % Set exposure time and gain of the camera.
    tlCamera.ExposureTime_us = 24534;
    tlCamera.Gain = 300;
    tlCamera.BlackLevel = 60;
    
    % ROI and Bin
    roiAndBin = tlCamera.ROIAndBin;
    roiAndBin.ROIOriginX_pixels = 0;
    roiAndBin.ROIWidth_pixels = 600;
    roiAndBin.ROIOriginY_pixels = 0;
    roiAndBin.ROIHeight_pixels = 600;
    roiAndBin.BinX = 2;
    roiAndBin.BinY = 2;
    tlCamera.ROIAndBin = roiAndBin;
    
    % Set the FIFO frame buffer size. Default size is 1.
    tlCamera.MaximumNumberOfFramesToQueue = 5;
    
    figure(1)
    
    % Start continuous image acquisition
    disp('Starting continuous image acquisition.');
    tlCamera.OperationMode = Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;
    tlCamera.FramesPerTrigger_zeroForUnlimited = 0;
    tlCamera.TriggerPolarity = Thorlabs.TSI.TLCameraInterfaces.TriggerPolarity.ActiveHigh;
    tlCamera.Arm;
    tlCamera.IssueSoftwareTrigger;
    maxPixelIntensity = double(2^tlCamera.BitDepth - 1);

end




FPS = 20;
adjustRange = [0.01 0.5];
% adjustRange = [0.11 0.22];;
delayAdjust = 0; %-0.00038;
% delayAdjust = -0.0001;
obj = VideoReader('D:\Dropbox (MIT)\Nhat\Pupil_diameter_testing/F21_changecameraangle.avi');

% INITIALIZATION =============================
FR = 1/FPS;
nFR = Dur*FPS;
pupilCenter = nan(nFR,2);
pupilPerim = nan(nFR,1);
tStamps = nan(nFR,1);
events = nan(nFR,1);
tElapsed = 0;
totFPS = 0;
showfig = 0;
adaptiveOn = 0;
convOn = 1;

frameidx = 1;


% DISPLAY AND SEGMENT FIRST IMAGE  =============================
%     [pointerCAM, ImageCAM] = OPEN_CAMERA_FAST;
%     I = GRAB_FRAME(pointerCAM,ImageCAM)';
% I = imread('f17frame6.png');
if ~usecam
    I = read(obj, frameidx);

    I = I(:,:,1); %first channel only
else
    % Check if image buffer has been filled
    I = get_img_frame(tlCamera);
end
I = imadjust(I,adjustRange,[]);

% Segment and fit first image
clear options;
options.showfig = showfig;
options.adaptive = adaptiveOn;
options.conv = convOn;
piel = segmentPupilONLINE(I,TH,options); % Segment Image
piel = selectPupilONLINE(piel); % Select closest region to center of image
Elp = fitEllipsePupilONLINE(piel); % Fit ellipse
if Elp.a == 0 || Elp.b == 0
    Elp.a = size(I,1);
    Elp.b = size(I,2);
    Elp.z = size(I)/2;
    Elp.alpha = 0;
end

% Open a figure window display pupil, fit, and header
figure;
subplot(121);
himage  = imagesc(I,[0 200]);
colormap gray
hold on
hElp = plotellipse(Elp.z, Elp.a, Elp.b, Elp.alpha);
hElp.LineWidth = 1;
hElp.LineStyle = ':';
hCenter = plot(Elp.z(1),Elp.z(2), 'y+','linewidth',1,'markersize',5);
axis off;
axis equal;
%     setUpPlot;
titleStr  = sprintf('Frame: %i T: %3.4f @ %3.2f (fps)\n',0,0,0);
hTitle = title(titleStr);

subplot(122);
imshow(piel);
hold on;
hElp2 = plotellipse(Elp.z, Elp.a, Elp.b, Elp.alpha);
hElp2.LineWidth = 1;
hElp2.Color = 'b';
hCenter2 = plot(Elp.z(1),Elp.z(2), 'y+','linewidth',1,'markersize',5);

% hElp2.LineStyle = ':';
    
t0 = tic;
i = 1;
    
while tElapsed < Dur
    tStamps(i) = toc(t0);

    % Get image & Segment image
%     I = imread('f17frame6.png');

    if ~usecam
        I = read(obj, frameidx);

        I = I(:,:,1); %first channel only
    else
        % Check if image buffer has been filled
        I = get_img_frame(tlCamera);
    end
    
    % put this in a subfunction
    
    I = imadjust(I,adjustRange,[]);
    piel = segmentPupilONLINE(I,TH,options); % Segment Image
    piel = selectPupilONLINE(piel); % Select closest region to center of image
    [Elp,pupilCenter(i,:),~,pupilPerim(i)] = fitEllipsePupilONLINE(piel); % Fit ellipse

    % Update image and fit
    subplot(121)
    set(himage,'Cdata',I); %drawnow;
    elpPlotData = elipsePlotData(Elp);
    set(hElp,'XData',elpPlotData(1,:),'YData',elpPlotData(2,:));
    set(hCenter,'XData',Elp.z(1),'YData',Elp.z(2)); drawnow;

    % Adjust timing to obtain desired frame rate
    tp = FR*i-(toc(t0)); % + delayAdjust;
    
    t2 = delay(tp);
    tElapsed = toc(t0);
    disp(tElapsed);
    totFPS = 1/(-tStamps(i)+tElapsed-delayAdjust) + totFPS;

    % Update text
    fprintf('time = %3.4f (s) FR =  %3.2f (fps) Perim = %4.1f Ev = %2.0f\n',tStamps(i),1/(-tStamps(i)+tElapsed),pupilPerim(i),events(i));
    titleStr = sprintf('Frame: %i T: %3.4f @ %3.2f (fps)\n',i,tStamps(i),1/(-tStamps(i)+tElapsed));
    set(hTitle,'String',titleStr);
    
    subplot(122);
    imshow(piel);
    hold on
    hElp2 = plotellipse(Elp.z, Elp.a, Elp.b, Elp.alpha);
    hElp2.LineWidth = 1;
    hElp2.Color = 'b';
    hCenter2 = plot(Elp.z(1),Elp.z(2), 'y+','linewidth',1,'markersize',5);

    i = i+1;
    frameidx = frameidx + 1;
end

% DISPLAY THE DATA =============================
% figure;
% ax(1) = subplot(5,1,1:3);
% plot(tStamps,pupilPerim,'k')
% setUpPlotCompact
% xlabel('Time (s)');
% ylabel('Pupil perimeter (pixel)');
% title('Pupil');
% YL = ylim;
% if YL(2) > 1000
%     YL(2) = prctile(pupilPerim,95);
% end
% ylim([YL(1) YL(2)]);
% 
% ax(2) = subplot(5,1,5);
% plot(tStamps,events,'-k','linewidth',2);
% ylim([-0.1 1.1]);
% title('Event')
% xlabel('Time (s)');
% setUpPlotCompact
% 
% linkaxes(ax,'x')
%% Release the serial numbers
delete(serialNumbers);

% Release the TLCameraSDK.
tlCameraSDK.Dispose;
delete(tlCameraSDK);
