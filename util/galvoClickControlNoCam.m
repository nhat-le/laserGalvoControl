global lsr obj
nidaqComm('init');
lsr = lsrCtrlParams;
obj.vidRes = [1000 1000];

load(fullfile(lsr.rootdir, 'calibration/galvoCal.mat'));

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

h4 = figure; 
% start(obj.vid);
% pause(0.05)
% trigger(obj.vid);
% pause(0.05);
% if strcmp(obj.camtype, 'DCx')
%     dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
% elseif strcmp(obj.camtype, 'new')
%     dataRead = get_img_frame(obj.cam);
% end
% dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
%getdata(obj.vid, obj.vid.FramesAvailable, 'uint16');
figure(h4), 
xlim([0 obj.vidRes(1)])
ylim([0 obj.vidRes(2)]);
set(gca,'XDir','reverse');
set(gca,'YDir','reverse');
% imagesc(dataRead(:,:,:,1)); 
% colormap gray; axis image; set(gca,'XDir','reverse');
title('Calibration test - Click a new location for the beam')

lsr.galvoTform = galvoCal.tform;
for ii=1:1000
  galvoHelper('calibration',h4)
end

% stop(obj.vid);
close(h4)

% park beam outside field of view
nidaqAOPulse('aoPulse',[-5 -5 0 0]);

function galvoHelper(mode,fh)

% galvoClickControl(mode,fh)
% moves the laser beam to where a cursor is clicked on the image
% mode is either 'experiment' for within-GUI tests, and 'calibration',
% called by galvoCal()

global obj lsr

if nargin < 1
  mode = 'experiment';
  fh   = obj.hImage;
elseif nargin == 1
  fh   = obj.hImage;
end

% vlsr = lsr.Vlsr;


ClickedPosition = round(ginputax(gca, 1));

if  ClickedPosition(1)>= 1             && ...
    ClickedPosition(1)<= obj.vidRes(1) && ...
    ClickedPosition(2)>= 1             && ...
    ClickedPosition(2)<= obj.vidRes(2)
  
  NewGalvoVoltage = transformPointsInverse(lsr.galvoTform,ClickedPosition);
  
  switch mode
    case 'experiment'
      lsr.galvoManualVx = NewGalvoVoltage(1);
      lsr.galvoManualVy = NewGalvoVoltage(2);
      lsr.dataout_manual.galvoXvec = ones(lsr.dataout_manual.vecLength,1).*lsr.galvoManualVx;
      lsr.dataout_manual.galvoYvec = ones(lsr.dataout_manual.vecLength,1).*lsr.galvoManualVy;
      
      dataout = zeros(1,4);
      dataout(LaserRigParameters.lsrSwitchCh) = 5;
      dataout(LaserRigParameters.lsrWaveCh)   = vlsr;
      dataout(LaserRigParameters.galvoCh(1)) = NewGalvoVoltage(1);
      dataout(LaserRigParameters.galvoCh(2)) = NewGalvoVoltage(2);
      nidaqAOPulse('aoPulse',dataout);
    case 'calibration'
      dataout = zeros(1,4);
%       dataout(LaserRigParameters.lsrSwitchCh) = 5;
%       dataout(LaserRigParameters.lsrWaveCh)   = vlsr;
%       nidaqAOPulse('aoPulse',dataout);
      
      dataout(LaserRigParameters.galvoCh(1)) = NewGalvoVoltage(1);
      dataout(LaserRigParameters.galvoCh(2)) = NewGalvoVoltage(2);
      nidaqAOPulse('aoPulse',dataout);
%       pause(0.10);
%       trigger(obj.vid);
%       pause(0.05);
%       dataRead = getdata(obj.vid, obj.vid.FramesAvailable, 'uint16');
%       dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
%       if strcmp(obj.camtype, 'DCx')
%           dataRead = thor_single_frame(obj.cam, obj.MemId, obj.camWidth, obj.camHeight, obj.Bits);
%       elseif strcmp(obj.camtype, 'new')
%           dataRead = get_img_frame(obj.cam);
%       end
%         figure(fh);
%       imagesc(dataRead(:,:,:,1)); colormap gray;
  end
  figure(fh);
  clf;
%   axis image; hold on; set(gca,'XDir','reverse');
  plot(ClickedPosition(1),ClickedPosition(2),'x');
  set(gca,'XDir','reverse');
  set(gca,'YDir','reverse');
  xlim([0 obj.vidRes(1)])
  ylim([0 obj.vidRes(2)])
  
end
end