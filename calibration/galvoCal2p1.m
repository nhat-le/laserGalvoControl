%% Mapping the XY Voltage values applied to the beam position in the camera FOV
% go through different positions of the laser and measure the position on the image observed
% 2D-Interpolate to get a continuous map of pixel-position vs voltage applied on the galvos.
% This function was written mostly by Stephan Thiberge, modified by Lucas Pinto

global obj lsr

obj.camtype = 'new';

if strcmp(obj.camtype, 'DCx')
    waitTime = 0.2;
else
    waitTime = 1;
end

if isempty(lsr)
    lsr = lsrCtrlParams;
end
commandwindow;
fprintf('calibrating galvos...\n')
nidaqComm('init');

% first save a copy of previous cal file (if any) by appending previous
% date
if ~isempty(dir(sprintf('%scalibration\\galvoCal.mat',lsr.rootdir)))
    load(sprintf('%scalibration\\galvoCal.mat',lsr.rootdir),'calDate')
    copyfile(sprintf('%scalibration\\galvoCal.mat',lsr.rootdir),...
        sprintf('%scalibration\\galvoCal_%s.mat',lsr.savepath,calDate), 'f')
    clear calDate
end

% conversion pixels/mm
% camera is 1920 x 1200
% n_vx = 1200; n_vy = 1920; 
% Vx moves beam along smaller image axis (cols, 1200 pxl), top -> bottom
% Vy moves beam along longer image axis(rows, 1920 pxl), right -> left
pxlPerMM      = lsr.pxlPerMM; % image scale
saveCalImFlag = 0; % save calibration images? (boolean)
calDate       = datestr(datetime,'yymmdd_HHMMSS');

% create video object
% imaqreset;
% LaserRigParams = LaserRigParameters;
% obj.vid = videoinput(LaserRigParams.camName, 1, LaserRigParams.camImageType);
% triggerconfig(obj.vid, 'manual');
% obj.vid.FramesPerTrigger = 1;
% obj.vid.TriggerRepeat    = Inf;
% src.ExposureMode         = 'Manual';
% src.Exposure             = -20;
% src.FrameRate            = 20;
% 
% start(obj.vid);
% Create video object, if not existing
if ~isfield(obj, 'cam')
    if strcmp(obj.camtype, 'DCx')
        NET.addAssembly('C:\Program Files\Thorlabs\Scientific Imaging\DCx Camera Support\Develop\DotNet\uc480DotNet.dll');
        obj.cam = uc480.Camera;

        obj.cam.Init(0);

        obj.cam.Display.Mode.Set(uc480.Defines.DisplayMode.DiB);
        obj.cam.PixelFormat.Set(uc480.Defines.ColorMode.RGB8Packed);
        obj.cam.Trigger.Set(uc480.Defines.TriggerMode.Software);

        % figure;
        [status,obj.MemId] = obj.cam.Memory.Allocate(true);
        if strcmp(status, 'NO_SUCCESS')
            error('Error allocating memory...')
        end

        [~,obj.camWidth,obj.camHeight,obj.Bits,~] = obj.cam.Memory.Inquire(obj.MemId);
        obj.vidRes = [obj.camWidth, obj.camHeight];
    elseif strcmp(obj.camtype, 'new')
        cd C:\Users\MMM_3p1_SI\Documents\laserGalvoControl\pupilVBP
        NET.addAssembly('C:\Users\MMM_3p1_SI\Documents\laserGalvoControl\pupilVBP\Thorlabs.TSI.TLCamera.dll');
        disp('Dot NET assembly loaded.');

        tlCameraSDK = Thorlabs.TSI.TLCamera.TLCameraSDK.OpenTLCameraSDK;

        % Get serial numbers of connected TLCameras.
        serialNumbers = tlCameraSDK.DiscoverAvailableCameras;
        disp([num2str(serialNumbers.Count), ' camera was discovered.']);

        % Open the first TLCamera using the serial number.
        disp('Opening the first camera')
        obj.cam = tlCameraSDK.OpenCamera(serialNumbers.Item(0), false);

        obj.cam.ExposureTime_us = 25000;
        obj.cam.Gain = 0;
        obj.cam.BlackLevel = 5;

        % ROI and Bin
        roiAndBin = obj.cam.ROIAndBin;
        roiAndBin.ROIOriginX_pixels = 0;
        roiAndBin.ROIWidth_pixels = 1920; %1500;
        roiAndBin.ROIOriginY_pixels = 0;
        roiAndBin.ROIHeight_pixels = 1200; %1000;
        roiAndBin.BinX = 1;
        roiAndBin.BinY = 1;
        obj.cam.ROIAndBin = roiAndBin;

        % Set the FIFO frame buffer size. Default size is 1.
        obj.cam.MaximumNumberOfFramesToQueue = 5;

        disp('Starting continuous image acquisition.');
        obj.cam.OperationMode = Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;
        obj.cam.FramesPerTrigger_zeroForUnlimited = 0;
        obj.cam.TriggerPolarity = Thorlabs.TSI.TLCameraInterfaces.TriggerPolarity.ActiveHigh;
        obj.cam.Arm;
        obj.cam.IssueSoftwareTrigger;
        maxPixelIntensity = double(2^obj.cam.BitDepth - 1);
    end
end

%% PREVIEW 
% visualize laser spot and set-up proper laser intensity for calibration
% Once done switch to next section.
dataout                                 = zeros(1,4);
dataout(LaserRigParameters.lsrSwitchCh) = 5;
dataout(LaserRigParameters.lsrWaveCh)   = .001; % very low power must be used for accurate localization of beam
nidaqAOPulse('aoPulse',dataout);

% Previewing the laser spot
if strcmp(obj.camtype, 'DCx')
    Data = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
elseif strcmp(obj.camtype, 'new')
    Data = get_img_frame(obj.cam);
end
% hImage = imshow(Data);
% hImage                                  = preview(obj.vid);
% handleAxes                              = ancestor(hImage,'axes');
% set(handleAxes,'XDir','reverse');

% pause(1)
% close(gcf);
%% Acquire the images for each position of the laser

% stoppreview(obj.vid);
% closepreview;

% video resolution for pxl-mm conversion
% if ~isfield(obj,'vidRes') || (isfield(obj,'vidRes') && isempty(obj.vidRes))
%     obj.vidRes = get(obj.vid, 'VideoResolution');
% end
% resX = obj.vidRes(1); resY = obj.vidRes(2);
% resX =  obj.camWidth; resY = obj.camHeight;
resX = size(Data, 2); resY = size(Data, 1);
obj.vidRes = [resX, resY];

% try start(obj.vid); end

% GridSizeX    = 11;
% GridSizeY    = 11;
GridSizeX = 5;
GridSizeY = 5;
% VxMin        = -1.5; VxMax = 1.5;
% VyMin        = -1.0; VyMax = 1.0;
VxMin = -0.2; VxMax = 0.2;
VyMin = -0.2; VyMax = 0.2;
data         = [];
GalvoVoltage = [];
% dataRead     = getdata(obj.vid, obj.vid.FramesAvailable, 'uint16'); %flush buffer

% h = figure; 
axes(obj.camfig);
for iX = 1:GridSizeX
  for iY = 1:GridSizeY
      Vx = (VxMax-VxMin)*(iX-1)/(GridSizeX-1) + VxMin;
      Vy = (VyMax-VyMin)*(iY-1)/(GridSizeY-1) + VyMin;

      dataout(LaserRigParameters.galvoCh(1)) = Vx;
      dataout(LaserRigParameters.galvoCh(2)) = Vy;

      nidaqAOPulse('aoPulse',dataout);

      pause(waitTime)
%       trigger(obj.vid);
      if strcmp(obj.camtype, 'DCx')
        dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
      elseif strcmp(obj.camtype, 'new')
        dataRead = get_img_frame(obj.cam);
      end
%       dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
      pause(waitTime);
%       dataRead = getdata(obj.vid, obj.vid.FramesAvailable, 'uint16');
      
% figure(h), 
      imagesc(dataRead(:,:,:,1)); colormap gray; axis image; set(gca,'XDir','reverse');
      title(sprintf('Different positions of the beam are being scanned: %d, %d', iX, iY))
      if iX==1 && iY==1
          data                  = dataRead(:,:,:,1);
          GalvoVoltage          = [Vx,Vy];
      elseif ~isempty(dataRead(:,:,:,1)) 
          data(:,:,:,end+1)     = dataRead(:,:,:,1);
          GalvoVoltage(end+1,:) = [Vx,Vy];
      end

  end
end
% stop(obj.vid);
nidaqAOPulse('aoPulse',[0 0 0 0]);

%% write images to tif stack?
numFrames = size(data, 4);

if saveCalImFlag

  Imfile = sprintf('%scalibration\\galvoCal_%s.tif',lsr.rootdir,calDate);

  imwrite(data(:,:,:,1), Imfile, 'WriteMode','overwrite');
  for ii = 2:numFrames
      try
          imwrite(data(:,:,:,ii), Imfile,'WriteMode','append','Description',num2str(GalvoVoltage(ii,:)));
      catch err
          disp(['Had to pause writing at image ',num2str(ii)]);
          pause(0.1);
          fid = fopen(Imfile, 'a');
          fclose(fid);
          if (fid ~= -1)
              imwrite(data(:,:,:,ii), Imfile,'WriteMode','append','Description',num2str(GalvoVoltage(ii,:)));
          else
              rethrow(err)
          end
      end
  end
end

% close(h)

%% 2-Create map of laser beam positions
Beam = [];
for ii = 1:numFrames
     MaxIntensityOfFrame(ii,:) = max(max(data(:,:,:,ii)));
end
IntensityOfSpot = max(MaxIntensityOfFrame(:));

% figure;
axes(obj.camfig);
for ii = 1:numFrames
    cla;
    disp(['location ',num2str(ii),' out of ',num2str(numFrames)])
    
    % acquire image and detect beam
%     BW         = im2bw(data(:,:,:,ii), 0.3);
    BW         = im2bw(data(:,:,:,ii), 0.01);
    structDisk = strel('disk', 5);
    bw2        = imdilate(BW, structDisk);
    bw2        = imclearborder(bw2);
    structDisk = strel('disk', 1);
    STATS      = [];
    STATS2     = regionprops(bw2, 'Centroid','Area');
    while ~isempty(STATS2)
        STATS=STATS2;
        bw3=bw2;
        bw2 = imerode(bw3,structDisk);
        STATS2 = regionprops(bw2, 'Centroid','Area');
    end
    
    % calculate beam position in the image
%     if length(STATS)~=1 || MaxIntensityOfFrame(ii)<(.50)*IntensityOfSpot
%         disp(['Ambiguity at frame ',num2str(ii),'. Dropping it.']);
%         Beam(ii,:)=[0 0];
%     else
%         Beam(ii,:)= STATS.Centroid;
%         imshow(BW)
%         hold on
%         scatter(STATS.Centroid(1), STATS.Centroid(2), 200, 'rx')
%         pause(2);
%     end

    imagesc(data(:,:,:,ii))
    hold on
    [xpos, ypos] = ginputax(gca, 1);
%     [xpos, ypos] = ginput(1);
    Beam(ii,:) = [xpos, ypos];
    
    
end

%% linear fit
BeamMM          = Beam./pxlPerMM;
galvoCal.BeamMM = BeamMM;

% Beam = rand(size(Beam));

maxVX = 1.3; minVX = -1.4;
maxVY = 1.5; minVY = -1.5;

% linear fit x and y galvo
idxx = GalvoVoltage(:,1)<=maxVX & GalvoVoltage(:,1)>=minVX & Beam(:,1)~=0;
idxy = GalvoVoltage(:,2)<=maxVY & GalvoVoltage(:,2)>=minVY & Beam(:,1)~=0;
id   = GalvoVoltage(:,1)<=maxVX & GalvoVoltage(:,1)>=minVX & ...
    Beam(:,1)~=0 & GalvoVoltage(:,2)<=maxVY & GalvoVoltage(:,2)>=minVY;

p = polyfit(GalvoVoltage(idxx & idxy,1),BeamMM(idxx & idxy,1),1);
galvoCal.linFit.slope_x    = p(1); 
galvoCal.linFit.constant_x = p(2);

p = polyfit(GalvoVoltage(idxx & idxy,2),BeamMM(idxx & idxy,2),1);
galvoCal.linFit.slope_y    = p(1); 
galvoCal.linFit.constant_y = p(2);

% find the (0V,0V) point, and the (.xxV,.xxV) point
idx0V0V = GalvoVoltage(:,1)==0 & GalvoVoltage(:,2)==0;
Vx = (VxMax-VxMin)*(GridSizeX- 4)/(GridSizeX-1) + VxMin;
Vy = (VyMax-VyMin)*(GridSizeX-4)/(GridSizeY-1) + VyMin;
idxxxVxxV = find(GalvoVoltage(:,1)==Vx & GalvoVoltage(:,2)==Vy);

%% affine voltage-to-pixel transformation

% What is the transformation Voltage to Pixels?
movingPoints   = GalvoVoltage(id,:); %in Volts
fixedPoints    = Beam(id,:); %inPixels
galvoCal.tform = fitgeotrans(movingPoints,fixedPoints,'affine'); % may have to change the option "affine" if using another lens

% Recover angle and scale of the transformation by checking how a unit 
% vector parallel to the x-axis is rotated and stretched.
u       = [0 1];
v       = [0 0];
[x, y]  = transformPointsForward(galvoCal.tform, u, v);
dx      = x(2) - x(1);
dy      = y(2) - y(1);
galvoCal.angle = (180/pi) * atan2(dy, dx);
galvoCal.scale = 1 / sqrt(dx^2 + dy^2);
disp('--------------------------------')
disp(['angle   = ',num2str(galvoCal.angle)]);
disp(['scale   = ',num2str(galvoCal.scale)]);
disp(['1/scale = ',num2str(1/galvoCal.scale)]);
disp('--------------------------------')

% Using the tform estimate to recalculate the beam positions function of
% voltages applied
CalculatedBeamPosition = transformPointsForward(galvoCal.tform, movingPoints);
dx                     = round(CalculatedBeamPosition(:,1)-fixedPoints(:,1));
dy                     = round(CalculatedBeamPosition(:,2)-fixedPoints(:,2));
stdDx                  = std(dx);
stdDy                  = std(dy);


%% save
save(sprintf('%scalibration\\galvoCal.mat',lsr.rootdir),'galvoCal','calDate')

copyfile(sprintf('%scalibration\\galvoCal.mat',lsr.rootdir),...
    sprintf('%scalibration\\galvoCal.mat',lsr.savepath), 'f')

%% plot results

% plot beam locations
h2=figure; 
set(gcf,'position',[10 50 700 900])

subplot(3,2,1); hold on; set(gca,'YDir','reverse'); set(gca,'XDir','reverse');% measured grid
imagesc(imabsdiff(data(:,:,:,idxxxVxxV),data(:,:,:,idx0V0V))); colormap gray; axis image;
plot(Beam(id,1),Beam(id,2),'x'); ylim([0 resY]); xlim([0 resX]);  %Beam(:,1)~=0
hold on;
plot(Beam(idx0V0V,1),Beam(idx0V0V,2),'o'); xlim([0 resX]); 
hold on;
plot(Beam(idxxxVxxV,1),Beam(idxxxVxxV,2),'o'); xlim([0 resX]); 



%plot original fitted position and calculated position
figure(h2); 
subplot(3,2,2), axis image; hold on; set(gca,'YDir','reverse'); set(gca,'XDir','reverse');
imagesc(imabsdiff(data(:,:,:,idxxxVxxV),data(:,:,:,idx0V0V))); colormap gray; hold on;
plot(Beam(id,1),Beam(id,2),'x'); ylim([0 resY]); xlim([0 resX]);  %Beam(:,1)~=0
hold on;
plot(CalculatedBeamPosition(:,1),CalculatedBeamPosition(:,2),'o'); ylim([0 resY]); xlim([0 resX]);  %Beam(:,1)~=0

subplot(3,2,3); hold on ;
xaxis = minVX:.01:maxVX;
plot(GalvoVoltage(id,1),BeamMM(id,1),'kx'); plot(xaxis,galvoCal.linFit.slope_x.*xaxis+galvoCal.linFit.constant_x,'r-')
xlabel('X-Galvo Voltage (V)'); ylabel('X-position (mm)');
%xlim([-.9 .5])
%subplot(2,2,4); hold on % beam x galvo voltage (y)

subplot(3,2,5); hold on ;
xaxis = minVY:.01:maxVY;
plot(GalvoVoltage(id,2),BeamMM(id,2),'kx'); plot(xaxis,galvoCal.linFit.slope_y.*xaxis+galvoCal.linFit.constant_y,'r-')
xlabel('Y-Galvo Voltage (V)'); ylabel('Y-position (mm)');
%xlim([-.9 .5])

subplot(3,2,4),hist(dx, -4:4); title('Pos - calculatedPos');
xlabel('Dx'); legend(['std=',num2str(round(100*stdDx)/100),'px (', num2str(round(1000*stdDx/pxlPerMM)),'um)'])

subplot(3,2,6),hist(dy, -4:4); xlabel('Dy'); legend(['std=',num2str(round(100*stdDy)/100),'px (', num2str(round(1000*stdDy/pxlPerMM)),'um)'])


figure(h2); 
h = annotation('textbox');
h.FontSize=10;
h.HorizontalAlignment='right';
h.String = ['angle : ',num2str(round(10*galvoCal.angle)/10),' deg      scaling : ',num2str(round(10/galvoCal.scale)/10),' px/V'];
h.Position=[0.64 0.92 0.2 0.04];

h2.PaperPositionMode='auto';
saveas(h2,sprintf('%scalibration\\galvoCalGraph_%s.pdf',lsr.savepath,calDate),'pdf')


%%

% Utility to verify calibration accuracy
% open a video window to diplay live image
% user clicks on the image
% a symbol appears where clicked and
% the beam should move to the new position indicated
dataout                                 = zeros(1,4);
dataout(LaserRigParameters.lsrSwitchCh) = 5;
dataout(LaserRigParameters.lsrWaveCh)   = 0.001;
nidaqAOPulse('aoPulse',dataout);

% h4 = figure; 
% start(obj.vid);
% pause(0.05)
% trigger(obj.vid);
% pause(0.05);
if strcmp(obj.camtype, 'DCx')
    dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
elseif strcmp(obj.camtype, 'new')
    dataRead = get_img_frame(obj.cam);
end
% dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
%getdata(obj.vid, obj.vid.FramesAvailable, 'uint16');
% figure(h4), 
axes(obj.camfig);
imagesc(dataRead(:,:,:,1)); 
colormap gray; axis image; set(gca,'XDir','reverse');
title('Calibration test - Click a new location for the beam')

lsr.galvoTform = galvoCal.tform;
for ii=1:10
  galvoClickControl('calibration')
end

% stop(obj.vid);
% close(h4)

% park beam outside field of view
nidaqAOPulse('aoPulse',[-5 -5 0 0]);

close(h2);