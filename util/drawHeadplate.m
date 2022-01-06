function drawHeadplate(impath,mouseID)
global lsr

% drawHeadplate(impath,mouseID)
% load image for mouse _mouseID_, and directory impath, plots it and
% prompts the user to draw headplate outline using roipoly()

refpath = dir([impath '*refIm.mat']);
load([impath refpath.name],'frame')

fh = figure;
imagesc(fliplr(frame))
caxis([55 1300])
colormap gray
% headplate        = roipoly;
h = drawellipse;
customWait(h);
headplate = createMask(h);
headplateContour = bwperim(headplate);
close(fh)

lsr.headplateOutline = headplateContour;
save([impath mouseID '_headplate.mat'],'headplateContour','headplate')

% Reload headplate outline
% load(sprintf('%s%s_headplate.mat',lsr.savepath,lsr.mouseID),'headplateContour')
[lsr.headplateOutlineY,lsr.headplateOutlineX] = find(fliplr(lsr.headplateOutline)==1);

end

function pos = customWait(hROI)

% Listen for mouse clicks on the ROI
l = addlistener(hROI,'ROIClicked',@clickCallback);

% Block program execution
uiwait;

% Remove listener
delete(l);

% Return the current position
pos = hROI.Position;

end

function clickCallback(~,evt)

if strcmp(evt.SelectionType,'double')
    uiresume;
end

end

