function drawHeadplate(impath,mouseID)
global lsr

% drawHeadplate(impath,mouseID)
% load image for mouse _mouseID_, and directory impath, plots it and
% prompts the user to draw headplate outline using roipoly()

refpath = dir([impath '*refIm.mat']);
load([impath refpath.name],'frame')

fh = figure;
imshow(fliplr(frame))
headplate        = roipoly;
headplateContour = bwperim(headplate);
close(fh)

lsr.headplateOutline = headplateContour;
save([impath mouseID '_headplate.mat'],'headplateContour','headplate')