% laserCtrlGUI
% GUI to control laser, galvos and video acquisition
%
% Lucas Pinto, Jan 2016
% Princeton Neuroscience Institute

%% INITIALIZE VARIABLES
global lsr obj

NET.addAssembly('C:\Program Files\Thorlabs\Scientific Imaging\DCx Camera Support\Develop\DotNet\uc480DotNet.dll');
nidaqComm('init')

lsr     = lsrCtrlParams; % get class object with laser parameters
lsr     = calculateP_on(lsr); % enforce max prob./location
lsr     = getCalValues(lsr); % get calibration parameters and quick-check laser power calibration
[lsr.galvoManualVx,lsr.galvoManualVy] = convertToGalvoVoltage([lsr.ML lsr.AP],'mm'); % galvo voltage
load(sprintf('%s\\grid\\fullGrid.mat',lsr.rootdir),'grid'); % load default grid
% lsr.grid        = grid;
% lsr.gridLabel   = 'fullGrid.mat';
lsr.locationSet = num2cell(1:size(lsr.grid,1));
lsr             = computeOuputData(lsr); % compute laser/galvo data output
lsr.fn          = sprintf('%s_%s',lsr.mouseID,datestr(datetime,'yyyymmdd_HHMMSS')); % default file name


%% start GUI and draw buttons
drawGUIfig; % nested function at the bottom

%% Intialize Galvo and lasers DAQ controls:
if LaserRigParameters.hasDAQ
  nidaqComm('init');
end

% update session log
updateConsole('session started')

% if last quick cal was performed longer than 48h ago, do it
set(obj.statusTxt,'foregroundcolor','r'); drawnow()
set(obj.statusTxt,'String','Performing quick power calibration...'); drawnow()
% lsr = quickPowerCal(lsr);
updateConsole(lsr.powerCalcheckMsg)
set(obj.statusTxt,'String','Idle','foregroundcolor',[.3 .3 .3])


%%
%==========================================================================
%% CAMERA CALLBACKS
%==========================================================================

% camera on/off
function camON_callback(~,event)
global obj

obj.camtype = 'new';


if get(obj.camON,'Value') == true 
  
  % create video input
  if ~isfield(obj,'cam')
      if strcmp(obj.camtype, 'DCx')
          obj.cam = uc480.Camera; 
          obj.cam.Init(0);

          obj.cam.Display.Mode.Set(uc480.Defines.DisplayMode.DiB);
          obj.cam.PixelFormat.Set(uc480.Defines.ColorMode.RGB8Packed);
          obj.cam.Trigger.Set(uc480.Defines.TriggerMode.Software);

          [status,obj.MemId] = obj.cam.Memory.Allocate(true);
          if strcmp(status, 'NO_SUCCESS')
              error('Error allocating memory...')
          end
          
          [~,obj.camWidth,obj.camHeight,obj.Bits,~] = obj.cam.Memory.Inquire(obj.MemId);
          obj.vidRes = [obj.camWidth, obj.camHeight];
          nBands = 3;
          obj.hImage = image(zeros(obj.vidRes(2),obj.vidRes(1), nBands),'Parent',obj.camfig);
      elseif strcmp(obj.camtype, 'new')
        % Load TLCamera DotNet assembly. The assembly .dll is assumed to be in the 
        % same folder as the scripts.
        % NET.addAssembly([pwd, '\Thorlabs.TSI.TLCamera.dll']);
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
        roiAndBin.ROIWidth_pixels = 1920;
        roiAndBin.ROIOriginY_pixels = 0;
        roiAndBin.ROIHeight_pixels = 1200;
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
%         maxPixelIntensity = double(2^obj.cam.BitDepth - 1);

        obj.hImage = image(zeros(roiAndBin.ROIHeight_pixels,roiAndBin.ROIWidth_pixels, 1),'Parent',obj.camfig);
        obj.vidRes = [roiAndBin.ROIWidth_pixels roiAndBin.ROIHeight_pixels];

      end


  end
  
  fprintf('Starting live feed...\n')
  camLoop2p1;
  
  % go into video data acquisition loop
%   try
%       camLoop;
%   catch
%       delete(obj.vid)
%       clear obj.vid
%       obj = createVideoObject(obj);
%       camLoop;
%   end

   
  
end
end

% save frame
function grabFrame_callback(~,event)
global obj lsr
if get(obj.grab,'Value') == true
  
  set(obj.camON,'Value',false);
  drawnow();
  camON_callback([],1);
  
  f1 = figure;
  set(f1,'visible','off')
  plotGalvoGrid(f1);
  
  uin = questdlg('save as reference image?'); % save?
  switch uin
    case 'Yes'
      thisfn = sprintf('%s%s_refIm',lsr.savepath,lsr.mouseID);
      uin2 = questdlg('set reference pixel?'); % prompt to change ref. pxl
      if strcmpi(uin2,'Yes')
        set(obj.setZero,'Value',1)
        setZero_callback([],1)
        set(obj.setZero,'Value',0)
      end
      lsr.refIm = obj.camData;
      
      % save as refIM and also with a date for recordkeeping
      frame = obj.camData; refPxl = lsr.refPxl;
      saveas(f1,sprintf('%s.fig',thisfn),'fig')
      save(thisfn,'frame','refPxl')
      imwrite(frame,sprintf('%s.tif',thisfn),'tif')
      
      % reset im registration
      lsr.imTform = [];
      
      thisls = dir(sprintf('%s%s_frameGrab*',lsr.savepath,lsr.fn));
      if isempty(thisls)
        thisfn = sprintf('%s%s_frameGrab',lsr.savepath,lsr.fn);
      else
        thisfn = sprintf('%s%s_frameGrab-%d',lsr.savepath,lsr.fn,length(thisls));
      end
      saveas(f1,sprintf('%s.fig',thisfn),'fig')
      save(thisfn,'frame','refPxl')
      imwrite(frame,sprintf('%s.tif',thisfn),'tif')
      
    case 'No'
      thisls = dir(sprintf('%s%s_frameGrab*',lsr.savepath,lsr.fn));
      if isempty(thisls)
        thisfn = sprintf('%s%s_frameGrab',lsr.savepath,lsr.fn);
      else
        thisfn = sprintf('%s%s_frameGrab-%d',lsr.savepath,lsr.fn,length(thisls));
      end
      lsr.currIm = obj.camData;
      
      frame = obj.camData; refPxl = lsr.refPxl;
      saveas(f1,sprintf('%s.fig',thisfn),'fig')
      save(thisfn,'frame','refPxl')
      imwrite(frame,sprintf('%s.tif',thisfn),'tif')
    case 'Cancel'
      close(f1)
  end
  
  set(f1,'visible','on','position',[20 20 obj.vidRes]);
  close(f1)
  updateConsole(sprintf('image saved to %s',thisfn))
  
  % prompt to register
  if strcmpi(uin,'No')
    uin3 = questdlg('register to reference image?');
    if strcmpi(uin3,'Yes')
      set(obj.registerIm,'Value',true)
      registerIm_callback([],1);
      set(obj.registerIm,'Value',false)
    end
  end
  plotGridAndHeadplate(obj.camfig);
end
end

% use mouse pointer/crosshair to set zero (bregma) on image
function setZero_callback(~,event)
global obj lsr
if get(obj.setZero,'Value') == true
  lsr.refPxl = ginputax(gca, 1);
  hold on; plot(lsr.refPxl(1),lsr.refPxl(2),'m+','markersize',10)
  lsr  = computeOuputData(lsr);
  updateConsole('set new reference pixel')
  plotGridAndHeadplate(obj.camfig);
end
end

% load stimulation grid
function grid_callback(~,event)
global obj lsr

if get(obj.grid,'Value') == true
  thisdir = pwd;
  cd([lsr.rootdir '\grid'])
  fn = uigetfile('*.mat','select grid file');
  cd(thisdir)
  
  % load grid and update parameters
  loadgrid([lsr.rootdir '\grid\' fn])
  
  % plot it
  plotGridAndHeadplate(obj.camfig);
end

end

function loadgrid(fn)

global lsr obj

load(fn,'grid','P_on')
% lsr.P_on        = P_on;
lsr.grid        = grid;
lsr.gridLabel   = fn;
lsr.locationSet = [];
% set(obj.pON,'String',num2str(lsr.P_on));
updateConsole(sprintf('loaded %s',fn))

if iscell(lsr.grid) % grid indicates simulatenous regions (each cell has the coordinates for those)
  for ii = 1:length(grid)
    lsr.locationSet{ii} = 1:size(lsr.grid{ii},1);
  end
else
  lsr.locationSet = num2cell(1:size(lsr.grid,1));
end

if ~strcmpi(lsr.gridLabel,'cfos.mat')
  lsr = computeOuputData(lsr);
end

end

% set stimulation grid with cursor
function setgrid_callback(~,event)
global obj lsr

if get(obj.setgrid,'Value') == true
  
  axes(obj.camfig); % focus
  cla
  imagesc(obj.camData); colormap gray; axis image;
  caxis([lsr.disp_min, lsr.disp_max]);
  % allen borders
    if ~isempty(lsr.borders) && get(obj.allen_toggle, 'Value')
      plot(obj.bordersOutlineY,obj.bordersOutlineX,'r.')
    end
  
  
  set(gca,'XDir','reverse','xtick',[],'ytick',[]);
  
  stopSelection = 0;
  grid       = [];
  while ~stopSelection % 778,30 refpxl is [xpos(pix) ypos(pix)], bottom is 0, top is 1000 (Y), left is 1200, right is 0 (X)
    pxlin         = round(ginputax(gca, 1));
    hold on
    plot(pxlin(1), pxlin(2), 'yx');
    x             = (-pxlin(1) + lsr.refPxl(1))/lsr.pxlPerMM;
    y             = (-pxlin(2) + lsr.refPxl(2))/lsr.pxlPerMM;
    grid(end+1,:) = [x y];
    uin = questdlg('Select more locations?');
    if strcmpi(uin,'Yes')
      stopSelection = 0;
    elseif strcmpi(uin,'No')
      stopSelection = 1;
    end
  end
  
  % save new grid
  thisdir = pwd;
  cd([lsr.rootdir '\grid'])
  fn = uiputfile('*.mat','save new grid as');
  save(fn,'grid')
  cd(thisdir)
  updateConsole(sprintf('new manual grid saved to %s',fn))
  
  % update output data etc
  lsr.grid        = grid;
  lsr.locationSet = num2cell(1:size(lsr.grid,1));
  lsr             = computeOuputData(lsr);
  
  % update lsr on prob. according to grid size if necessary
  prevPon = lsr.P_on;
  if numel(lsr.locationSet) > 1/lsr.maxPonPerLoc && prevPon <= lsr.maxPonPerLoc
    lsr.P_on = 0.8;
  end
  
  lsr = calculateP_on(lsr);
  
  if prevPon > lsr.P_on
%     set(obj.pON,'String',num2str(lsr.P_on));
    updateConsole(sprintf('laser on prob. capped at %1.2f',lsr.P_on))
  elseif prevPon < lsr.P_on
%     set(obj.pON,'String',num2str(lsr.P_on));
    updateConsole(sprintf('laser on prob. automatically increased to %1.2f',lsr.P_on))
  end
  P_on = lsr.P_on;
  cd([lsr.rootdir '\grid'])
  save(fn,'P_on','-append')
  cd(thisdir)
  
  % plot it
  plotGridAndHeadplate(obj.camfig);
end
end

% register iamge
function registerIm_callback(~,event)
global obj lsr

if isempty(lsr.mouseID)
    errordlg('No mouse ID selected')
    return;
end


if get(obj.registerIm,'Value') == true
    thisdir = pwd;
    cd(lsr.savepath)
%     [fname, path] = uigetfile('*.tif','select image');
    refImg = imread(obj.imgpath);
%     refImg = imread(fullfile(path, fname));
    cd(thisdir)
    lsr.currIm  = obj.camData; 
  
  
  set(obj.statusTxt,'String','performing Im regsitration...')
  drawnow()
  
  obj.tform =  opto_img_align(refImg', obj.camData);
  
  % Warp the border image
%   w = images.geotrans.Warper(obj.tform, size(refImg));
%   centerOutput = affineO
    
  
  
%   [regMsg,lsr.okFlag] = registerImage(lsr.refIm,lsr.currIm,false);
%   wd = warndlg(regMsg,'Registration output');

  set(obj.statusTxt,'String','Idle')
  updateConsole('image registered')
end

end

% load stimulation grid
function drawHeadplate_callback(~,event)
global obj lsr

if get(obj.drawHeadplate,'Value') == true
  % manually draw headplate
  drawHeadplate(lsr.savepath,lsr.mouseID)
  
  % plot it
  plotGridAndHeadplate(obj.camfig);
end

end


% Green LED ON/OFF callback
function ledGreen_callback(~,event)

global obj
obj.LEDdataout(LaserRigParameters.LEDIdxGreen) = get(obj.LEDgreen,'Value');

if LaserRigParameters.hasDAQ
  nidaqDOwrite('writeDO',obj.LEDdataout)
end

end

% IR LED ON/OFF callback
function ledIR_callback(~,event)

global obj
obj.LEDdataout(LaserRigParameters.LEDIdxIR) = get(obj.LEDir,'Value');

if LaserRigParameters.hasDAQ
  nidaqDOwrite('writeDO',obj.LEDdataout)
end

end

%%
%==========================================================================
%% GENERAL CTRL CALLBACKS
%==========================================================================

% set directory for file saving
function cd_callback(~,event)
global obj lsr
if event == true || get(obj.sdir,'Value') == true
  lsr.savepath = uigetdir(lsr.rootdir,'Pick a directory');
  refreshFn_callback([],1);
end
end

% select mouse
function subjList_callback(~,event)

global obj lsr

if strcmpi(obj.subjList{get(obj.subjListDrop,'Value')},'add new')
  newmouse = inputdlg({'mouse ID:'});
  obj.animalListObj = obj.animalListObj.addToList(newmouse);
  lsr.mouseID = newmouse{1};
  refreshFn_callback([],1);
  set(obj.subjListDrop,'String',obj.animalListObj.mouseList)
  set(obj.subjListDrop,'Value',length(obj.animalListObj.mouseList)-1)
else
  midx        = get(obj.subjListDrop,'Value');
  lsr.mouseID = obj.subjList{midx};
  refreshFn_callback([],1);
end

% create directory for animal if necessary
if isempty(dir(sprintf('%s%s',lsr.savepathroot,lsr.mouseID)))
  mkdir(sprintf('%s%s',lsr.savepathroot,lsr.mouseID));
end

% change savepath
lsr.savepath = [lsr.savepathroot lsr.mouseID '\'];

% load reference image
if ~isempty(dir(sprintf('%s%s_refIm.mat',lsr.savepath,lsr.mouseID)))
  load(sprintf('%s%s_refIm',lsr.savepath,lsr.mouseID),'frame','refPxl')
  lsr.refIm  = frame;
  lsr.refPxl = refPxl;
else
  thish = warndlg('reference image not found');
end

% load headplate outline
if ~isempty(dir(sprintf('%s%s_headplate.mat',lsr.savepath,lsr.mouseID)))
  load(sprintf('%s%s_headplate.mat',lsr.savepath,lsr.mouseID),'headplateContour')
  lsr.headplateOutline = headplateContour;
  [lsr.headplateOutlineY,lsr.headplateOutlineX] = find(fliplr(lsr.headplateOutline)==1);
else
  thish = warndlg('headplate outline not found');
end

% retrieve and set default parameters for this animal
power    = animalList.powerList{midx};
grid     = animalList.gridList{midx};
varpower = animalList.varPower(midx);

% Load template
templateDir = animalList.templateDir{midx};
files = dir(fullfile(templateDir, 'atlas*.mat'));
if (numel(files) ~= 1)
    errordlg('Invalid animal')
    return
end
load(fullfile(files(1).folder, files(1).name), 'borders', 'opts');
lsr.borders = borders;
% outline stored here is constant for each animal (reflecting the template
% stored)
[lsr.bordersOutlineX,lsr.bordersOutlineY] = find(borders==1); %TODO: do we need to transform?

%outline stored here can change subject to alignment warp
[obj.bordersOutlineX,obj.bordersOutlineY] = find(borders==1);

% Load and store cluster locations for inactivation
files = dir(fullfile(templateDir, 'cluster_points.mat'));
assert(numel(files) == 1);
load(fullfile(files(1).folder, files(1).name), 'motor_coords', 'visual_coords', ...
    'frontal_coords', 'rsc_coords');
lsr.clusterPoints = struct;
lsr.clusterPoints.motor_coords = motor_coords;
lsr.clusterPoints.frontal_coords = frontal_coords;
lsr.clusterPoints.visual_coords = visual_coords;
lsr.clusterPoints.rsc_coords = rsc_coords;

obj.imgpath = opts.imgpath;

epoch    = animalList.epochList{midx};
epochVal = find(strcmpi(lsr.epochList,epoch));

% set(obj.power,'String', num2str(power)); laserpower([],true);
% set(obj.epoch,'Value' , epochVal);       epoch_callback([],true)
% set(obj.varypower,'Value',varpower);     varypower_callback([],true);
% loadgrid([lsr.rootdir '\grid\' grid])

if isfield(obj,'camData'); plotGridAndHeadplate(obj.camfig); end
updateConsole(sprintf('Parameters for animal %s loaded', lsr.mouseID))

obj.tform = [];

% Load the laser calibration for the animal
try
    load(sprintf('%scalibration\\galvoCal.mat',lsr.savepath), 'galvoCal');
    lsr.galvoTform = galvoCal.tform;
    clear galvoCal
catch e
    if strcmp(e.identifier, 'MATLAB:load:couldNotReadFile')
         warndlg('Warning: no galvo calibration file found')
    end
end


% runOnLsr = animalList.runOnLsr(midx);
% if runOnLsr
%   thish = warndlg('Run this mouse on laser');
% else
%   thish = warndlg('Just training for this mouse');
% end

end

% file name
function fn_callback(~,event)
global obj lsr
lsr.fn = get(obj.fnenter,'String');
end

% refresh file name
function refreshFn_callback(~,event)
global obj lsr
lsr.fn = sprintf('%s_%s',lsr.mouseID,datestr(datetime,'yyyymmdd_HHMMSS'));
set(obj.fnenter,'String',lsr.fn)
end

% reset
function reset_callback(~,event)
global obj lsr
if get(obj.resetgui,'Value') == true
  if isempty(lsr.console_fn) || isempty(dir(lsr.console_fn))
    usrin = questdlg('save session log?');
    if strcmpi(usrin,'Yes')
      saveConsole([],1);
    end
  end
  
  % close daq communication
  if LaserRigParameters.hasDAQ == true
    nidaqComm('end');
  end
  close(obj.fig); clear
  laserCtrlGUI
end
end

% quit GUI
function quitgui_callback(~,event)
global obj lsr
obj.cam.Exit;

if get(obj.quitgui,'Value') == true
  if isempty(lsr.console_fn) || isempty(dir(lsr.console_fn))
    usrin = questdlg('save session log?');
    if strcmpi(usrin,'Yes')
      saveConsole([],1);
    end
  end
  % close daq communication
  if LaserRigParameters.hasDAQ == true
    nidaqComm('end');
  end
  close(obj.fig); clear
end

end

%%
% =========================================================================
%% LASER PARAMETER CALLBACKS
%==========================================================================

% set source (manual or external trigger)
function src_callback(~,event)
global obj lsr
if strcmpi(get(obj.src.SelectedObject,'string'),'manual')
  lsr.manualTrigger = true;
else
  lsr.manualTrigger = false;
end
end

function clusters_callback(~,event)
global obj lsr
lsr.activeCluster = get(obj.clusters.SelectedObject,'string');

% Update grid positions
if ~isempty(lsr.clusterPoints)
    grid = [];
    activeSet = lsr.clusterPoints.(sprintf('%s_coords', lsr.activeCluster));
    for i = 1:size(activeSet, 1)
        x             = (-activeSet(i,1) + lsr.refPxl(1))/lsr.pxlPerMM;
        y             = (-activeSet(i,2) + lsr.refPxl(2))/lsr.pxlPerMM;
        grid(end+1,:) = [x y];
    end
    
    % apply transform if exists
    if ~isempty(obj.tform)
        grid_pixX = lsr.refPxl(1) - grid(:,1) * lsr.pxlPerMM;
        grid_pixY = lsr.refPxl(2) - grid(:,2) * lsr.pxlPerMM;

        grid_pix_trans = transformPointsForward(obj.tform, [grid_pixY, grid_pixX]);

        grid_mmX_trans = (-grid_pix_trans(:,1) + lsr.refPxl(1)) / lsr.pxlPerMM;
        grid_mmY_trans = (-grid_pix_trans(:,2) + lsr.refPxl(2)) / lsr.pxlPerMM;

        grid = [grid_mmX_trans, grid_mmY_trans];
        
    end
    
    % save new grid
    thisdir = pwd;
    cd([lsr.rootdir '\grid'])
    fn = uiputfile('*.mat','save new grid as');
    save(fn,'grid')
    cd(thisdir)
    updateConsole(sprintf('new grid saved to %s',fn))

    % update output data etc
    lsr.grid        = grid;
    lsr.locationSet = num2cell(1:size(lsr.grid,1));
    lsr             = computeOuputData(lsr);
end

updateConsole(sprintf('cluster location changed to %s',lsr.activeCluster))

end

% set pulse frequency
function pulsedur(~,event)
global obj lsr
lsr.freq = str2double(get(obj.pulsedur,'String'));
lsr = computeOuputData(lsr);
updateConsole(sprintf('pulse duration changed to %s ms',get(obj.pulsedur,'String')))
end

% set min display
function disp_min(~,event)
global obj lsr
lsr.disp_min = str2double(get(obj.disp_min,'String'));
updateConsole(sprintf('display min changed to %s',get(obj.disp_min,'String')))
end

% set max display
function disp_max(~,event)
global obj lsr
lsr.disp_max = str2double(get(obj.disp_max,'String'));
% lsr = computeOuputData(lsr);
updateConsole(sprintf('display max changed to %s',get(obj.disp_max,'String')))
end

function headplatetoggle_callback(~,event)
global obj
show_headplate = get(obj.headplate_toggle, 'Value');
updateConsole(sprintf('Headplate toggled: %d', show_headplate))

end

function allentoggle_callback(~,event)
global obj
show_borders = get(obj.allen_toggle, 'Value');
updateConsole(sprintf('Allen toggled: %d', show_borders))

end

function galvosweepsave_callback(~,event)
global obj
savesweep = get(obj.galvosweepsave, 'Value');
updateConsole(sprintf('Save sweep toggled: %d', savesweep))

end

function autoscale_callback(~,event)
global obj lsr

lsr.disp_min = min(obj.camData(:));
lsr.disp_max = max(obj.camData(:));
set(obj.disp_min,'String', num2str(lsr.disp_min))
set(obj.disp_max,'String', num2str(lsr.disp_max))

updateConsole('Auto-scaled')

end

% set laser power with input box
function laserpower(~,event)
global obj lsr

% first make sure it doesn't exceed max voltage, then update
pp = str2double(get(obj.power,'String')); %#ok<*ST2NM>
if pp <= lsr.maxP
  lsr.power = pp;
else
  lsr.power = lsr.maxP;
  warndlg('Power exceeds allowed max, set to max')
end
lsr.Vlsr = (lsr.power-lsr.b_power)/lsr.a_power;
lsr = computeOuputData(lsr);
updateConsole(sprintf('laser power changed to %1.1f mW',lsr.power))
end

% set ramp dpwn duartion with input box
function rampdowndur(~,event)
global obj lsr

lsr.rampDownDur = str2double(get(obj.rampdown,'String'));
updateConsole(sprintf('ramp down duration changed to %s s',get(obj.rampdown,'String')))
end

% set laser ON trial probability with input box
function pON_callback(~,event)
global obj lsr

lsr.P_on = str2double(get(obj.pON,'String'));
lsr = calculateP_on(lsr);
set(obj.pON,'String',num2str(lsr.P_on));
updateConsole(sprintf('laser on prob. changed to %1.2f',lsr.P_on))
end

% select laser ON trial epoch with drop down menu
function epoch_callback(~,event)
global obj lsr

lsr.epoch   = lsr.epochList{get(obj.epoch,'Value')};
updateConsole(sprintf('trial epoch changed to %s',lsr.epoch))

end

% select ramp down method with drop down menu
function rampmethod_callback(~,event)
global obj lsr

lsr.rampDownMode = lsr.rampDownList{get(obj.rampmethod,'Value')};
updateConsole(sprintf('ramp down mode changed to %s',lsr.rampDownMode))
end

% select laser ON trial epoch with drop down menu
function trialdraw_callback(~,event)
global obj lsr

lsr.drawMode = lsr.drawModeList{get(obj.trialdraw,'Value')};
updateConsole(sprintf('trial drawing method changed to %s',lsr.drawMode))
end

% select laser ON trial epoch with drop down menu
function varypower_callback(~,event)
global obj lsr

lsr.varyPower = get(obj.varypower,'Value');
if lsr.varyPower
  updateConsole(sprintf('laser power will be randomly varied'))
else
  updateConsole(sprintf('constant laser power'))
end
end

% set AP position with text input
function posX_callback(~,event)
global obj lsr
lsr.AP = str2double(get(obj.posY,'String'));
lsr.ML = str2double(get(obj.posX,'String'));

[lsr.galvoManualVx,lsr.galvoManualVy] = convertToGalvoVoltage([lsr.ML lsr.AP],'mm');
lsr = computeOuputData(lsr);

dataout = zeros(1,4);
dataout(LaserRigParameters.galvoCh(1)) =lsr.galvoManualVx;
dataout(LaserRigParameters.galvoCh(2)) = lsr.galvoManualVy;
nidaqAOPulse('aoPulse',dataout);

updateConsole('galvo position manually updated')

end

% set ML position with text input
function posY_callback(~,event)
global obj lsr

lsr.AP = str2double(get(obj.posY,'String'));
lsr.ML = str2double(get(obj.posX,'String'));

[lsr.galvoManualVx,lsr.galvoManualVy] = convertToGalvoVoltage([lsr.ML lsr.AP],'mm');
lsr = computeOuputData(lsr);

dataout = zeros(1,4);
dataout(LaserRigParameters.galvoCh(1)) =lsr.galvoManualVx;
dataout(LaserRigParameters.galvoCh(2)) = lsr.galvoManualVy;
nidaqAOPulse('aoPulse',dataout);

updateConsole('galvo position manually updated')

end

% select galvo location with cursor
function manualGalvo_callback(~,event)
global obj lsr

if get(obj.manualSelect,'Value') == true
  galvoClickControl;
  updateConsole('galvo position manually updated')
end

end

% execute new galvo position
function goto_callback(~,event)
global obj lsr
if get(obj.goToPos,'Value') == true && lsr.manualTrigger == true
  dataout = zeros(1,4);
  dataout(LaserRigParameters.galvoCh(1))  = lsr.dataout_manual.galvoXvec(1);
  dataout(LaserRigParameters.galvoCh(2))  = lsr.dataout_manual.galvoYvec(1);
  dataout(LaserRigParameters.lsrWaveCh)   = lsr.dataout_manual.lsrVec(1);
  dataout(LaserRigParameters.lsrSwitchCh) = 5;
  
  nidaqAOPulse('aoPulse',dataout);
  % update status
  set(obj.statusTxt,'foregroundColor','b')
  set(obj.statusTxt,'String','constant pulse')
  updateConsole('Pulse started')
elseif get(obj.goToPos,'Value') == true && lsr.manualTrigger == false
  warndlg('Please enable manual trigger first')
else
  
  nidaqAOPulse('aoPulse',[0 0 0 0]);
  % update status
  set(obj.statusTxt,'foregroundColor',[.3 .3 .3])
  set(obj.statusTxt,'String','Idle')
  updateConsole('Pulse turned off')
end

end

% laser on / off
function pulse_callback(~,event)
global obj lsr
if get(obj.pulse,'Value') == true && lsr.manualTrigger == true
  if get(obj.camON,'Value') == true % can't run loop and read cam at the same time
    
  else
      updateConsole('Started pulse protocol...');
    laserLoop;
      updateConsole('Pulse protocol finished!');
  end
  
elseif get(obj.pulse,'Value') == true && lsr.manualTrigger == false
  warndlg('Please enable manual trigger first')
end
end

% start behavioral experiment
function ready_callback(~,event)
global obj lsr
if get(obj.ready,'Value') == true
  if lsr.manualTrigger == true
    warndlg('Please enable external trigger first')
  else
    if lsr.okFlag
      laserLoop;
      lsr.okFlag = false;
    else
      warndlg('Aligment is off. Please fix before proceding')
    end
  end
end
end

%%
% =========================================================================
%% EXPERIMENT CONTROL CALLBACKS
%==========================================================================

function deleteInstructions(src,event)
global obj
if sum(get(obj.logTxt,'foregroundcolor')) > 0
  set(obj.logTxt,'String','','foregroundcolor',[0 0 0]);
end
end

% save notes to text file
function saveNotes(~,event)
global obj lsr

% time stamp for note
temp = datetime;
calDate = datestr(temp,'HH:MM:SS');
lsr.note_fn=[lsr.savepath '\experNotes' lsr.fn '.txt'];

% creating or appending?
if isempty(dir(lsr.note_fn))
  obj.noteAppended = 0;
else
  obj.noteAppended = 1;
end

% retrieve note and save to .txt file
set(obj.logTxt,'Selected','off');
thisstr = get(obj.logTxt,'String');
while isempty(thisstr)
  thisstr = get(obj.logTxt,'String');
end

thisstr = textwrap({thisstr},30);
fid = fopen(lsr.note_fn,'a+');
fprintf(fid,'\nnote at %sh\n',calDate);
for ii = 1:length(thisstr)
  fprintf(fid,'%s\r\n',thisstr{ii});
end
fprintf(fid,'\r\n');
fclose(fid);

% reset box and output action
set(obj.logTxt,'String','Enter notes here','foregroundcolor',[.7 .7 .7]);
if obj.noteAppended
  updateConsole(sprintf('appended to experNotes%s',lsr.fn))
else
  updateConsole(sprintf('created experNotes%s',lsr.fn))
end
end

% save console to text file
function saveConsole(~,event)
global obj lsr

lsr.console_fn=[lsr.savepath '\sessionLog' lsr.fn '.txt'];

% retrieve note and save to .txt file
thisstr = get(obj.outputTxt,'String');
fid = fopen(lsr.console_fn,'a+');
for ii = 1:length(thisstr)
  fprintf(fid,'\r\n%s',thisstr{ii});
end
fprintf(fid,'\r\n');
fclose(fid);

% reset console
set(obj.outputTxt,'String', ...
  {'------------------------------------------'; ...
  ['        ' datestr(datetime)]              ; ...
  '------------------------------------------'; ...
  ''                                         });

end

%%
% =========================================================================
%% CALIBRATION CALLBACKS
%==========================================================================

% power
function powercal_callback(~,event)
global obj lsr
if get(obj.powercal,'Value') == true
  powerCal;
  figure(obj.fig)
  updateConsole('power calibration')
  lsr = getCalValues(lsr);
  lsr = computeOuputData(lsr);
end
end

% galvos
function galvocal_callback(~,event)
global obj lsr
if isempty(lsr.mouseID)
    errordlg('Please select mouse ID')
    return
end

if get(obj.galvocal,'Value') == true
  galvoCal2p1;
  figure(obj.fig)
  updateConsole('galvo calibration')
  lsr = getCalValues(lsr);
  lsr = computeOuputData(lsr);
end
end

% sweep galvos
function galvosweep_callback(~,event)
global obj lsr

savesweep = get(obj.galvosweepsave, 'Value');
currdate = datetime;
currdate.Format = 'yyyy-MM-dd';
datestr = string(currdate);
% Sweep the selected points
if get(obj.galvosweep,'Value') == true
    dataout = zeros(1,4);
    dataout(LaserRigParameters.lsrSwitchCh) = 5;
    dataout(LaserRigParameters.lsrWaveCh)   = lsr.Vlsr;
    
    axes(obj.camfig);
    for niter = 1
        for i=1:size(lsr.grid, 1)
            gridpoint = lsr.grid(i,:);
            [Vx, Vy] = convertToGalvoVoltage(gridpoint, 'mm');

            dataout(LaserRigParameters.galvoCh(1)) = Vx;
            dataout(LaserRigParameters.galvoCh(2)) = Vy;

            nidaqAOPulse('aoPulse',dataout);

            % Show camera image
            pause(1)
            if strcmp(obj.camtype, 'DCx')
                dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
            elseif strcmp(obj.camtype, 'new')
                dataRead = get_img_frame(obj.cam);
            end
    %         pause(waitTime);
            obj.camData = dataRead(:,:,:,end);
            
            % Save if requested..
            if savesweep
                if isempty(lsr.mouseID)
                    errordlg('Error: no mouse ID selected')
                end
                savepath = sprintf('%s%s_%s_galvosweep.tif',...
                    lsr.savepath,lsr.mouseID,datestr);
                if i == 1
                    imwrite(obj.camData, savepath);
                else
                    imwrite(obj.camData, savepath,'WriteMode','append');
                end
                
                
            end

            % plot
            plotGridAndHeadplate(obj.camfig)

    %         imagesc(dataRead(:,:,:,1)); colormap gray; axis image; set(gca,'XDir','reverse');
    % 
            
        end
    end
    
    dataout = zeros(1,4);
    nidaqAOPulse('aoPulse',dataout);
end



end

%%
% =========================================================================
%% PRESET CALLBACKS
%==========================================================================


% example preset used in ephys confirmation experiments (Pinto et al 2019)
function ephyspreset_callback(~,event)
global obj lsr
if get(obj.ephyspreset,'Value') == true
  load([lsr.rootdir '\grid\ephys.mat'],'grid','locDur','cycleDur','powers','ntrials','rampDown')
  updateConsole('loaded ephys.mat')
  lsr.grid            = grid;
  lsr.gridLabel       = 'ephys.mat';
  lsr.preSetOn        = true;
  lsr.presetLocDur    = locDur; % duration per setim spot in sec
  lsr.presetCycleDur  = cycleDur; % total cycle duration in sec
  lsr.presetNTrials   = ntrials; % expt duration in min
  lsr.presetMaxDurMin = inf;
  lsr.presetPowers    = powers;
  lsr.presetRampDown  = rampDown;
  lsr.ephys           = true;
  
  for ii = 1:length(powers)
    lsr.Vlsr_preset(ii) = (powers(ii)-lsr.b_power)/lsr.a_power;
  end
  lsr.Vlsr_preset(lsr.Vlsr_preset>5) = 5;
  lsr.locationSet = [];
  
  if iscell(lsr.grid) % grid indicates simulatenous regions (each cell has the coordinates for those)
    for ii = 1:length(grid)
      lsr.locationSet{ii} = 1:size(lsr.grid{ii},1);
    end
  else
    lsr.locationSet = num2cell(1:size(lsr.grid,1));
  end

  lsr      = computeOuputDataPreSetEphys(lsr);
  
  plotGridAndHeadplate(obj.camfig);
  
  laserLoop;
end
end

%%
% =========================================================================
%% DRAW GUI OBJECT
function drawGUIfig
global obj lsr

obj.animalListObj = animalList;
obj.subjList = obj.animalListObj.mouseList;
% obj.subjList{end+1} = 'add new';
obj.consoleInitString = {'------------------------------------------'; ...
                         ['        ' datestr(datetime)]              ; ...
                         '------------------------------------------'; ...
                         ''                                         };

% create video object
% imaqreset;
% obj.vid = videoinput('pointgrey', 1, 'F7_Mono16_1920x1200_Mode7');
        
% create GUI figure
ss = get(groot,'screensize');
ss = ss(3:4);
obj.fig    =   figure    ('Name',               'Laser and Display Controls',     ...
                          'NumberTitle',        'off',              ...
                          'Position',           round([ss(1)*.1 ss(2)*.1 ss(1)*.8 ss(2)*.8]));

% -------------------------------------------------------------------------
%% general controls
% -------------------------------------------------------------------------
obj.subjtxt   =   uicontrol (obj.fig,                               ...
                        'Style',                'text',             ...
                        'String',               'Mouse ID:',        ...
                        'Units',                'normalized',       ...
                        'Position',             [.028 .052 .07 .04],...
                        'horizontalAlignment',  'left',             ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold');
obj.subjListDrop =   uicontrol (obj.fig,                            ...
                        'Style',                'popupmenu',        ...
                        'String',               obj.subjList,       ...
                        'Units',                'normalized',       ...
                        'Position',             [.028 .02 .08 .038],...
                        'horizontalAlignment',  'left',             ...
                        'fontsize',             13,                 ...
                        'Callback',             @subjList_callback);
obj.fntxt   =   uicontrol (obj.fig,                                 ...
                        'Style',                'text',             ...
                        'String',               'File name:',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.14 .052 .07 .04],  ...
                        'horizontalAlignment',  'left',             ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold');
obj.fnenter =   uicontrol (obj.fig,                                 ...
                        'Style',                'edit',             ...
                        'String',               lsr.fn,             ...
                        'Units',                'normalized',       ...
                        'Position',             [.14 .022 .15 .038],...
                        'horizontalAlignment',  'left',             ...
                        'fontsize',             13,                 ...
                        'Callback',             @fn_callback);                    
obj.refreshFn   =   uicontrol (obj.fig,                             ...
                        'String',               'refresh',          ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.291 .0225 .05 .038],...
                        'Callback',             @refreshFn_callback,...
                        'fontsize',             12);
obj.sdir   =   uicontrol (obj.fig,                                  ...
                        'String',               'set dir',          ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.40 .02 .07 .05],  ...
                        'Callback',             @cd_callback,       ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold');
obj.resetgui   =   uicontrol (obj.fig,                              ...
                        'String',               'RESET',            ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.47 .02 .07 .05],  ...
                        'Callback',             @reset_callback,    ...
                        'fontsize',             13,                 ...
                        'foregroundColor',      [1 .6 .1],          ...
                        'fontweight',           'bold');
obj.quitgui =   uicontrol (obj.fig,                                 ...
                        'String',               'QUIT',             ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.54 .02 .07 .05],  ...
                        'foregroundColor',      [1 0 0],            ...
                        'Callback',             @quitgui_callback,  ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold'); 

                    
% -------------------------------------------------------------------------                   
%% camera feedback panel
% -------------------------------------------------------------------------

obj.vidpan  =   uipanel   ('Parent',            obj.fig,            ...
                        'Title',                'Camera',           ...
                        'Units',                'normalized',       ...
                        'Position',             [.03 .1 .58 .86],   ...
                        'fontsize',             14,                 ...
                        'fontweight',           'bold');
obj.camfig  =   axes      ('units',             'normalized',       ...
                        'position',             [.02 .15 .96 .8],   ...
                        'parent',               obj.vidpan,         ...
                        'visible',              'off',              ...
                        'xtick',                [],                 ...
                        'ytick',                []);
obj.camON   =   uicontrol (obj.vidpan,                              ...
                        'String',               'cam ON',           ...
                        'Style',                'togglebutton',     ...
                        'Units',                'normalized',       ...
                        'Position',             [.01 .02 .10 .07],  ...
                        'Callback',              @camON_callback,   ...
                        'fontsize',             13);
obj.grab    =   uicontrol (obj.vidpan,                              ...
                        'String',               'grab frame',       ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.115 .02 .10 .07], ...
                        'Callback',             @grabFrame_callback,...
                        'fontsize',             13); 
obj.registerIm    =   uicontrol (obj.vidpan,                        ...
                        'String',               'register',         ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.22 .02 .10 .07],  ...
                        'Callback',             @registerIm_callback,...
                        'fontsize',             13); 
obj.setZero =   uicontrol (obj.vidpan,                              ...
                        'String',               'set zero',         ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.325 .02 .10 .07], ...
                        'Callback',              @setZero_callback, ...
                        'fontsize',             13);
obj.grid    =   uicontrol (obj.vidpan,                              ...
                        'String',               'load grid',        ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.43 .02 .10 .07],  ...
                        'Callback',             @grid_callback,     ...
                        'fontsize',             13);
obj.setgrid =   uicontrol (obj.vidpan,                              ...
                        'String',               'set grid',         ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.535 .02 .10 .07], ...
                        'Callback',             @setgrid_callback,  ...
                        'fontsize',             13);
obj.drawHeadplate =   uicontrol (obj.vidpan,                        ...
                        'String',               'draw plate' ,      ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.64 .02 .10 .07],  ...
                        'Callback',             @drawHeadplate_callback,  ...
                        'fontsize',             12);
obj.LEDir      =   uicontrol (obj.vidpan,                           ...
                        'String',               'IR LED',           ...
                         'Style',                'togglebutton',    ...
                        'Units',                'normalized',       ...
                        'Position',             [.745 .02 .12 .07], ...
                        'Callback',             @ledIR_callback,    ...
                        'foregroundcolor',      [.5 0 0],           ...
                        'fontsize',             13);
obj.LEDgreen    =   uicontrol (obj.vidpan,                          ...
                        'String',               'Green LED',        ...
                        'Style',                'togglebutton',     ...
                        'Units',                'normalized',       ...
                        'Position',             [.87 .02 .12 .07],  ...
                        'Callback',             @ledGreen_callback, ...
                        'foregroundcolor',      [0 .5 0],           ...
                        'fontsize',             13);

obj.LEDdataout = zeros(1,numel(LaserRigParameters.doChannelsLED));

% -------------------------------------------------------------------------
%% laser control
% -------------------------------------------------------------------------
obj.laserpan =  uipanel ('Parent',              obj.fig,            ...
                        'Title',                'Laser and Display Controls',    ...
                        'Units',                'normalized',       ...
                        'Position',             [.62 .58 .35 .38],  ...
                        'fontsize',             14,                 ...
                        'foregroundcolor',      'k',                ...
                        'fontweight',           'bold'); 

% laser parameters   
obj.laserparams =  uipanel ('Parent',           obj.laserpan,       ...
                        'Title',                'Parameters',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .02 .55 .96],  ...
                        'foregroundcolor',      [.5 .5 .5],         ...
                        'fontsize',             13);
                       % 'fontweight',           'bold'); 
obj.pulsedur_txt = uicontrol(obj.laserparams,                           ...
                        'Style',                'text',             ...
                        'String',               'Pulse duration (ms):',...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .896 .55 .08], ...
                        'horizontalAlignment',  'right',            ...
                        'fontsize',             13);
obj.pulsedur =    uicontrol (obj.laserparams,                           ...
                        'String',               num2str(lsr.freq),  ...
                        'Style',                'edit',             ...
                        'Units',                'normalized',       ...
                        'Position',             [.65 .89 .3 .08],   ...
                        'Callback',             @pulsedur,         ...
                        'fontsize',             13);
obj.disp_min_txt = uicontrol (obj.laserparams,                           ...
                        'Style',                'text',             ...
                        'String',               'Display min',    ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .806 .55 .08], ...
                        'horizontalAlignment',  'right',            ...
                        'fontsize',13);
obj.disp_min = uicontrol     (obj.laserparams,                           ...
                        'String',               num2str(lsr.disp_min),   ...
                        'Style',                'edit',             ...
                        'Units',                'normalized',       ...
                        'Position',             [.65 .80 .3 .08],   ...
                        'Callback',             @disp_min,          ...
                        'fontsize',             13);
obj.disp_max_txt = uicontrol(obj.laserparams,                        ...
                        'Style',                'text',             ...
                        'String',               'Display max',      ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .716 .55 .08], ...
                        'horizontalAlignment',  'right',            ...
                        'fontsize',             13);
obj.disp_max = uicontrol(obj.laserparams,                           ...
                        'String',               num2str(lsr.disp_max), ...
                        'Style',                'edit',             ...
                        'Units',                'normalized',       ...
                        'Position',             [.65 .71 .3 .08],   ...
                        'Callback',             @disp_max,         ...
                        'fontsize',             13);
                    
obj.autoscale =   uicontrol (obj.laserparams,                              ...
                    'String',               'Auto-scale',         ...
                    'Style',                'pushbutton',       ...
                    'Units',                'normalized',       ...
                    'Position',             [0.65,0.4,0.3,0.2], ...
                    'Callback',             @autoscale_callback,  ...
                    'fontsize',             13,...
                    'FontWeight',           'bold');
                
obj.headplate_toggle =   uicontrol (obj.laserparams,                              ...
                    'String',               'Headplate',         ...
                    'Style',                'checkbox',       ...
                    'Units',                'normalized',       ...
                    'Position',             [0.65,0.2,0.3,0.2], ...
                    'Callback',             @headplatetoggle_callback,  ...
                    'fontsize',             10,...
                    'FontWeight',           'normal');
                
                
obj.allen_toggle =   uicontrol (obj.laserparams,                              ...
                    'String',               'Borders',         ...
                    'Style',                'checkbox',       ...
                    'Units',                'normalized',       ...
                    'Position',             [0.65,0.05,0.3,0.2], ...
                    'Callback',             @allentoggle_callback,  ...
                    'fontsize',             10,...
                    'FontWeight',           'normal');                
% obj.power_txt = uicontrol(obj.laserparams,                          ...
%                         'Style',                'text',             ...
%                         'String',               'Power (mW):',      ...
%                         'Units',                'normalized',       ...
%                         'Position',             [.02 .626 .55 .08], ...
%                         'horizontalAlignment',  'right',            ...
%                         'fontsize',             13);
% obj.power = uicontrol   (obj.laserparams,                           ...
%                         'Style',                'edit',             ...
%                         'Units',                'normalized',       ...
%                         'String',               num2str(lsr.power), ...
%                         'Position',             [.65 .62 .3 .08],    ...
%                         'Callback',             @laserpower,        ...
%                         'fontsize',             13);
% obj.rampdown_txt = uicontrol(obj.laserparams,                       ...
%                         'Style',                'text',             ...
%                         'String',               'Ramp down dur. (s):',...
%                         'Units',                'normalized',       ...
%                         'Position',             [.02 .536 .55 .08], ...
%                         'horizontalAlignment',  'right',            ...
%                         'fontsize',             13);
% obj.rampdown = uicontrol   (obj.laserparams,                        ...
%                         'Style',                'edit',             ...
%                         'Units',                'normalized',       ...
%                         'String',               sprintf('%1.1f',lsr.rampDownDur), ...
%                         'Position',             [.65 .53 .3 .08],   ...
%                         'Callback',             @rampdowndur,       ...
%                         'fontsize',             13);
% obj.pON_txt = uicontrol (obj.laserparams,                           ...
%                         'Style',                'text',             ...
%                         'String',               'P (on):',          ...
%                         'Units',                'normalized',       ...
%                         'Position',             [.02 .446 .55 .08], ...
%                         'horizontalAlignment',  'right',            ...
%                         'fontsize',             13);
% obj.pON = uicontrol     (obj.laserparams,                           ...
%                         'Style',                'edit',             ...
%                         'Units',                'normalized',       ...
%                         'String',               num2str(lsr.P_on),  ...
%                         'Position',             [.65 .44 .3 .08],   ...
%                         'Callback',             @pON_callback,      ...
%                         'fontsize',             13);
% obj.epoch_txt = uicontrol (obj.laserparams,                         ...
%                         'Style',                'text',             ...
%                         'String',               'Trial epoch:',     ...
%                         'Units',                'normalized',       ...
%                         'Position',             [.02 .33 .55 .08], ...
%                         'horizontalAlignment',  'right',            ...
%                         'fontsize',             13);
% obj.epoch = uicontrol   (obj.laserparams,                           ...
%                         'Style',                'popupmenu',        ...
%                         'Units',                'normalized',       ...
%                         'String',               lsr.epochList,      ...
%                         'Value',                strmatch(lsr.epoch,lsr.epochList),...
%                         'Position',             [.65 .36 .3 .05],   ...
%                         'Callback',             @epoch_callback,    ...
%                         'fontsize',             10);       
% obj.trialdraw_txt = uicontrol (obj.laserparams,                     ...
%                         'Style',                'text',             ...
%                         'String',               'Trial draw:',      ...
%                         'Units',                'normalized',       ...
%                         'Position',             [.02 .22 .55 .08],  ...
%                         'horizontalAlignment',  'right',            ...
%                         'fontsize',             13);
% obj.trialdraw = uicontrol   (obj.laserparams,                       ...
%                         'Style',                'popupmenu',        ...
%                         'Units',                'normalized',       ...
%                         'String',               lsr.drawModeList,   ...
%                         'Value',                strmatch(lsr.drawMode,lsr.drawModeList),...
%                         'Position',             [.65 .25 .3 .05],   ...
%                         'Callback',             @trialdraw_callback,...
%                         'fontsize',             10);     
% obj.rampmethod_txt = uicontrol (obj.laserparams,                    ...
%                         'Style',                'text',             ...
%                         'String',               'Ramp down method:',...
%                         'Units',                'normalized',       ...
%                         'Position',             [.02 .11 .55 .08],  ...
%                         'horizontalAlignment',  'right',            ...
%                         'fontsize',             13);
% obj.rampmethod = uicontrol   (obj.laserparams,                      ...
%                         'Style',                'popupmenu',        ...
%                         'Units',                'normalized',       ...
%                         'String',               lsr.rampDownList,   ...
%                         'Value',                strmatch(lsr.rampDownMode,lsr.rampDownList),...
%                         'Position',             [.65 .14 .3 .05],   ...
%                         'Callback',             @rampmethod_callback,...
%                         'fontsize',             10);     
% obj.varypower_txt = uicontrol (obj.laserparams,                    ...
%                         'Style',                'text',             ...
%                         'String',               'vary laser power',...
%                         'Units',                'normalized',       ...
%                         'Position',             [.02 .02 .55 .08],  ...
%                         'horizontalAlignment',  'right',            ...
%                         'fontsize',             13);
% obj.varypower = uicontrol   (obj.laserparams,                      ...
%                         'Style',                'checkbox',        ...
%                         'Units',                'normalized',      ...
%                         'Value',                lsr.varyPower,     ...
%                         'Position',             [.65 .02 .05 .05],  ...
%                         'Callback',             @varypower_callback,...
%                         'fontsize',             10);                         
% cluster locations
obj.clusters = uibuttongroup ('Parent',              obj.laserparams,       ...
                        'Units',                'normalized',       ...
                        'Position',             [0.1,0.05,0.39,0.6],   ...
                        'title',                'Cluster',          ...
                        'selectionChangedFcn',  @clusters_callback,      ...
                        'foregroundcolor',      [.5 .5 .5],         ...
                        'fontsize',             13);
obj.frontal = uicontrol     (obj.clusters,                                   ...
                        'String',               'frontal',           ...
                        'Style',                'radiobutton',      ...
                        'Units',                'normalized',       ...
                        'Value',                1,                  ...
                        'Position',             [.1 .0 .8 .4],     ...
                        'fontsize',             12);
obj.motor = uicontrol     (obj.clusters,                                   ...
                        'String',               'motor',         ...
                        'Style',                'radiobutton',      ...
                        'Units',                'normalized',       ...
                        'Value',                0,                  ...
                        'Position',             [.1 .25 .8 .4],    ...
                        'fontsize',             12);
obj.visual = uicontrol     (obj.clusters,                                   ...
                        'String',               'visual',         ...
                        'Style',                'radiobutton',      ...
                        'Units',                'normalized',       ...
                        'Value',                0,                  ...
                        'Position',             [.1 .5 .8 .4],    ...
                        'fontsize',             12);
                    
obj.rsc = uicontrol     (obj.clusters,                                   ...
                        'String',               'rsc',         ...
                        'Style',                'radiobutton',      ...
                        'Units',                'normalized',       ...
                        'Value',                0,                  ...
                        'Position',             [.1 .75 .8 .4],    ...
                        'fontsize',             12);
                    
% Source location
obj.src = uibuttongroup ('Parent',              obj.laserpan,       ...
                        'Units',                'normalized',       ...
                        'Position',             [.59 .68 .39 .3],   ...
                        'title',                'Trigger',          ...
                        'selectionChangedFcn',  @src_callback,      ...
                        'foregroundcolor',      [.5 .5 .5],         ...
                        'fontsize',             13);
obj.man = uicontrol     (obj.src,                                   ...
                        'String',               'manual',           ...
                        'Style',                'radiobutton',      ...
                        'Units',                'normalized',       ...
                        'Value',                1,                  ...
                        'Position',             [.02 .5 .8 .4],     ...
                        'fontsize',             12);
obj.ext = uicontrol     (obj.src,                                   ...
                        'String',               'external',         ...
                        'Style',                'radiobutton',      ...
                        'Units',                'normalized',       ...
                        'Value',                0,                  ...
                        'Position',             [.02 .05 .8 .4],    ...
                        'fontsize',             12);
                    
                    
                    
                    
                
% manual galvo control
obj.galvopan =  uipanel ('Parent',              obj.laserpan,       ...
                        'Title',                'Galvo (mm from zero)',...
                        'Units',                'normalized',       ...
                        'Position',             [.59 .28 .39 .38],  ...
                        'foregroundcolor',      [.5 .5 .5],         ...
                        'fontsize',             13);
obj.posX_txt = uicontrol(obj.galvopan,                              ...
                        'String',               'ML:',              ...
                        'Style',                'text',             ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .55 .2 .3],    ...
                        'fontsize',             13,                 ...
                        'horizontalalignment',  'left');
obj.posX = uicontrol    (obj.galvopan,                              ...
                        'String',               sprintf('%1.2f',lsr.AP),...
                        'Style',                'edit',             ...
                        'Units',                'normalized',       ...
                        'Position',             [.20 .6 .23 .3],    ...
                        'Callback',             @posX_callback,     ...
                        'fontsize',             13);
obj.posY_txt = uicontrol(obj.galvopan,                              ...
                        'String',               'AP:',              ...
                        'Style',                'text',             ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .15 .2 .3],    ...
                        'fontsize',             13,                 ...
                        'horizontalalignment',  'left');
obj.posY = uicontrol    (obj.galvopan,                              ...
                        'String',               sprintf('%1.2f',lsr.ML), ...
                        'Style',                'edit',             ...
                        'Units',                'normalized',       ...
                        'Position',             [.20 .2 .23 .3],    ...
                        'Callback',             @posY_callback,     ...
                        'fontsize',             13); 
obj.manualSelect = uicontrol (obj.galvopan,                         ...
                        'String',               'Cursor',           ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.46 .59 .49 .3],   ...
                        'Callback',             @manualGalvo_callback,...
                        'fontsize',             13);
obj.goToPos = uicontrol (obj.galvopan,                              ...
                        'String',               'Single Pulse',     ...
                        'Style',                'togglebutton',     ...
                        'Units',                'normalized',       ...
                        'Position',             [.46 .19 .49 .3],   ...
                        'Callback',             @goto_callback,     ...
                        'fontsize',             13);

% laser control buttons
obj.pulse = uicontrol   (obj.laserpan,                              ...
                        'String',               'Manual ON',        ...
                        'Style',                'togglebutton',     ...
                        'Units',                'normalized',       ...
                        'Position',             [.587 .02 .195 .25],...
                        'Callback',             @pulse_callback,    ...
                        'foregroundcolor',      'b',                ...
                        'fontsize',             13,                 ...
                        'horizontalAlignment',  'center',           ...
                        'fontweight',           'bold');
obj.ready = uicontrol   (obj.laserpan,                              ...                              
                        'String',               'Behavior PC',      ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.785 .02 .195 .25],...
                        'Callback',             @ready_callback,    ...
                        'foregroundcolor',      [0 .5 0],           ...
                        'fontsize',             13,                 ...
                        'horizontalAlignment',  'center',           ...
                        'fontweight',           'bold');

% -------------------------------------------------------------------------                    
%% experiment control
% -------------------------------------------------------------------------  
obj.tabgrp = uitabgroup (obj.fig,                                   ...
                        'Units',                'normalized',       ...
                        'Position',             [.62 .01 .35 .56]);

obj.exppan = uitab      (obj.tabgrp,                                ...
                        'Title',                'Experiment');            


obj.statuspan = uipanel ('Parent',              obj.exppan,         ...
                        'Title',                'Status',           ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .83 .96 .15],  ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold');
obj.statusTxt = uicontrol(obj.statuspan,                            ...
                        'Style',                'text',             ...
                        'String',               'Idle',             ...
                        'ForegroundColor',      [.3 .3 .3],         ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .02 .96 .90],  ...
                        'horizontalAlignment',  'left',             ...
                        'fontsize',             12,                 ...
                        'Callback',             @status_callback);
obj.outputpan = uipanel ('Parent',              obj.exppan,         ...
                        'Title',                'Console',          ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .29 .96 .52],  ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold');
obj.outputTxt = uicontrol(obj.outputpan,                            ...
                        'Style',                'listbox',             ...
                        'String',               obj.consoleInitString,...
                        'Value',                numel(obj.consoleInitString),...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .02 .96 .96],  ...
                        'horizontalAlignment',  'left',             ...
                        'fontsize',             12,                 ...
                        'backgroundColor',      'w',                ...
                        'Callback',             @output_callback);
obj.logTxt = uicontrol  (obj.exppan,                                ...
                        'Style',                'edit',             ...
                        'String',               'Enter notes here (left click first)', ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .02 .72 .25],  ...
                        'horizontalAlignment',  'left',             ...
                        'Max',                  2,                  ...
                        'fontsize',             12,                 ...
                        'foregroundcolor',      [.7 .7 .7],         ...
                        'ButtonDownFcn',        @deleteInstructions);
obj.saveLog = uicontrol(obj.exppan,                                 ...
                        'Style',                'pushbutton',       ...
                        'String',               'save note',        ...
                        'Units',                'normalized',       ...
                        'fontsize',             13,                 ...
                        'Position',             [.76 .02 .22 .09],  ...
                        'callBack',             @saveNotes);
obj.saveConsole = uicontrol(obj.exppan,                             ...
                        'Style',                'pushbutton',       ...
                        'String',               'save console',     ...
                        'Units',                'normalized',       ...
                        'fontsize',             13,                 ...
                        'Position',             [.76 .12 .22 .09],  ...
                        'callBack',             @saveConsole);

% -------------------------------------------------------------------------                    
%% calibration
% -------------------------------------------------------------------------  
obj.calpan = uitab      (obj.tabgrp,                                ...
                        'Title',                'Calibration tools');
                    
% control buttons
obj.galvocal = uicontrol   (obj.calpan,                             ...
                        'String',               'Calibrate galvos', ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.1 .6 .35 .25],    ...
                        'Callback',             @galvocal_callback, ...
                        'foregroundcolor',      'k',                ...
                        'fontsize',             13,                 ...
                        'horizontalAlignment',  'center',           ...
                        'fontweight',           'bold');
obj.galvosweep = uicontrol   (obj.calpan,                           ...
                        'String',               'Galvo sweep',      ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.1 .3 .35 .25],    ...
                        'Callback',             @galvosweep_callback,...
                        'foregroundcolor',      'k',                ...
                        'fontsize',             13,                 ...
                        'horizontalAlignment',  'center',           ...
                        'fontweight',           'bold');
                    
obj.galvosweepsave = uicontrol   (obj.calpan,                           ...
                        'String',               'Save',      ...
                        'Style',                'checkbox',       ...
                        'Units',                'normalized',       ...
                        'Position',             [0.5,0.3,0.35,0.25],    ...
                        'Callback',             @galvosweepsave_callback,...
                        'fontsize',             10,                 ...
                        'fontweight',           'normal');
       
% obj.powercal = uicontrol   (obj.calpan,                             ...                              
%                         'String',               'Calibrate power',  ...
%                         'Style',                'pushbutton',       ...
%                         'Units',                'normalized',       ...
%                         'Position',             [.5 .6 .35 .25],    ...
%                         'Callback',             @powercal_callback, ...
%                         'foregroundcolor',      'k',                ...
%                         'fontsize',             13,                 ...
%                         'horizontalAlignment',  'center',           ...
%                         'fontweight',           'bold');
                    
                    
% -----------------------------------------------
%% presets
% -----------------------------------------------

obj.presetpan = uitab      (obj.tabgrp,                             ...
                        'Title',                'Presets');   


obj.ephyspreset = uicontrol   (obj.presetpan,                       ...                              
                        'String',               'Ephys',            ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.1 .05 .35 .25],   ...
                        'Callback',             @ephyspreset_callback,...
                        'foregroundcolor',      'b',                ...
                        'fontsize',             13,                 ...
                        'horizontalAlignment',  'center',           ...
                        'fontweight',           'bold');
end