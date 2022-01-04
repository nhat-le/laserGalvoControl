function dataTracking = trackAsURecV2(Dur,PROOT,FNSave)
%New version reads from an Arduino instead of NIDAQ

close all; clc;

% DEFAULT PARAMETERS =============================
% Dur = 1800;
% PROOT = 'C:\data\Vincent\Pupil\Pupil - Sound\CtlAmp\G133\';
% FNSave = 'G133_6diffFreq1';
% TH = 0.8;
TH = 2.55;

FPS = 20;
adjustRange = [0.01 0.5];
adjustRange = [0.01 0.5];
% adjustRange = [0.11 0.22];
showfig = 0;
adaptiveOn = 0;
convOn = 1;
delayAdjust = -0.00038;
% delayAdjust = -0.0001;

% CHECK UPS =============================
addpath([pwd '\helpers\']);
if nargin < 3 
    
    FNSave = '';
    if nargin < 2
        PROOT = pwd;
        if nargin < 1
            Dur = 3800;
        end
    end
end
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



try
    % DISPLAY AND SEGMENT FIRST IMAGE  =============================
%     [pointerCAM, ImageCAM] = OPEN_CAMERA_FAST;
%     I = GRAB_FRAME(pointerCAM,ImageCAM)';
    I = imread('f17frame6.png');
    I = I(:,:,1); %first channel only
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
    
    % CARD INITIALIZATION FOR EVENT IN  =============================
%     ardIn = arduino_cardSetUpInOutV3;
    
    
    % RECORD AND TRACK =============================
    % Pre-initialization
%     t0 = tic;
%     arduino_readArduinoV3(ardIn,t0);
%     t0 = tic;
% 
%     i = 1;

    
    while tElapsed < Dur
        tStamps(i) = toc(t0);
        
        % Read arduino
        d = arduino_readArduinoV3(ardIn,t0);
        events(i) = mean(d(:,3)); % AVERAGE OF INPUT 2 on ARDUINO

        
        % Get image & Segment image
        I = GRAB_FRAME(pointerCAM,ImageCAM)';  
        I = imadjust(I,adjustRange,[]);
        piel = segmentPupilONLINE(I,TH,options); % Segment Image
        piel = selectPupilONLINE(piel); % Select closest region to center of image
        [Elp,pupilCenter(i,:),~,pupilPerim(i)] = fitEllipsePupilONLINE(piel); % Fit ellipse

        % Update image and fit
        set(himage,'Cdata',I); %drawnow;
        elpPlotData = elipsePlotData(Elp);
        set(hElp,'XData',elpPlotData(1,:),'YData',elpPlotData(2,:));
        set(hCenter,'XData',Elp.z(1),'YData',Elp.z(2)); drawnow;
        
        % Adjust timing to obtain desired frame rate
        tp = FR*i-(toc(t0)) + delayAdjust;
        waitVBP(tp);
        tElapsed = toc(t0);
        totFPS = 1/(-tStamps(i)+tElapsed-delayAdjust) + totFPS;
        
        % Update text
        fprintf('time = %3.4f (s) FR =  %3.2f (fps) Perim = %4.1f Ev = %2.0f\n',tStamps(i),1/(-tStamps(i)+tElapsed-delayAdjust),pupilPerim(i),events(i));
        titleStr = sprintf('Frame: %i T: %3.4f @ %3.2f (fps)\n',i,tStamps(i),1/(-tStamps(i)+tElapsed-delayAdjust));
        set(hTitle,'String',titleStr);
        
        i = i+1;
    end
    %     close all;
    CLOSE_CAMERA(pointerCAM,ImageCAM);
catch ME
        
    %     close all;
    fprintf('ERROR DURING TRY\n');
    ME
    CLOSE_CAMERA(pointerCAM,ImageCAM);
    arduino_resetArduinoIn(ardIn)
end
fprintf('AVG FPS = %3.2f (Hz)\n', totFPS/i);
arduino_resetArduinoIn(ardIn);

% SAVE DATA =============================
dataTracking.perim = pupilPerim;
dataTracking.tStamps = tStamps;
dataTracking.center = pupilCenter;
dataTracking.events = events;

dataTracking.settings.fps = FPS;
dataTracking.settings.duration = Dur;
dataTracking.settings.threshold = TH;
dataTracking.settings.delayAdjust = delayAdjust;
dataTracking.settings.adjustRange = adjustRange;
dataTracking.settings.adaptiveOn = adaptiveOn;
dataTracking.settings.convOn = convOn;
dataTracking.settings.dateRecorded = clock;
dataTracking.settings.originalFName = FNSave;

if exist(PROOT,'dir')
    uisave('dataTracking', [PROOT '\' FNSave '_dataTracking']);
else
    uisave('dataTracking',[pwd '\' FNSave '_dataTracking']);
end

% DISPLAY THE DATA =============================
figure;
ax(1) = subplot(5,1,1:3);
plot(tStamps,pupilPerim,'k')
setUpPlotCompact
xlabel('Time (s)');
ylabel('Pupil perimeter (pixel)');
title('Pupil');
YL = ylim;
if YL(2) > 1000
    YL(2) = prctile(pupilPerim,95);
end
ylim([YL(1) YL(2)]);

ax(2) = subplot(5,1,5);
plot(tStamps,events,'-k','linewidth',2);
ylim([-0.1 1.1]);
title('Event')
xlabel('Time (s)');
setUpPlotCompact

linkaxes(ax,'x')
