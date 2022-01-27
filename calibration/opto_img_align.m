function tform = opto_img_align(ref, im)
%ref, im: arrays representing the reference and image to align
global obj lsr

%% Load the reference and data images
% Resize singleImg to match dimensions of reference
% im = imresize(im, size(ref));

% TODO: determine if we need to flip the images

%% Get points for alignment
figure('Position', [39 378 961 420]);
subplot(122);
imagesc(im);
axis image
view([90 -90])
set(gca,'XDir','reverse','xtick',[],'ytick',[]);
lowlim = prctile(im(:), 1);
upperlim = prctile(im(:), 95);
caxis([lowlim, upperlim]);

colormap gray
subplot(121)
imagesc(ref);
axis image
view([90 -90])
set(gca,'XDir','normal','YDir', 'normal', 'xtick',[],'ytick',[]);

lowlim = prctile(ref(:), 1);
upperlim = prctile(ref(:), 99);
caxis([lowlim, upperlim]);
hold on
title('Select landmarks on the reference, then press enter');
[x1,y1] = getpts;
refPoints=[x1 y1];
plot(refPoints(:,1),refPoints(:,2),'xw','linewidth',2);
labelArr = {};
for i = 1:size(refPoints, 1)
    labelArr{i} = num2str(i);
end
text(refPoints(:,1) + 10,refPoints(:,2) + 10, labelArr, 'Color', 'w');

subplot(122)
imagesc(im);
axis image
view([90 -90])
set(gca,'XDir','reverse','xtick',[],'ytick',[]);
lowlim = prctile(im(:), 1);
upperlim = prctile(im(:), 95);
caxis([lowlim, upperlim]);

hold on
title('Select landmarks on the data, then press enter');
[x2,y2] = getpts;
imgPoints=[x2 y2];
plot(imgPoints(:,1),imgPoints(:,2),'xw','linewidth',2);


%% Align the images
affine = 0;
if affine, affinestr='affine'; else, affinestr='nonreflectivesimilarity'; end
tform = fitgeotrans(refPoints, imgPoints, affinestr);
rotpoints = transformPointsForward(tform,refPoints);

transformedpts = transformPointsForward(tform, [lsr.bordersOutlineX, lsr.bordersOutlineY]);
obj.bordersOutlineX = transformedpts(:,2);
obj.bordersOutlineY = transformedpts(:,1);

subplot(122)
imagesc(im)
hold on
plot(transformedpts(:,1), transformedpts(:,2),'r.')
title('Raw image')

plot(rotpoints(:,1),rotpoints(:,2),'xw','linewidth',2);
plot(imgPoints(:,1),imgPoints(:,2),'xr','linewidth',2);

subplot(121)

%% apply transform to grid
%mm to pixel
grid_pixX = lsr.refPxl(1) - lsr.grid(:,1) * lsr.pxlPerMM;
grid_pixY = lsr.refPxl(2) - lsr.grid(:,2) * lsr.pxlPerMM;

grid_pix_trans = transformPointsForward(tform, [grid_pixY, grid_pixX]);

grid_mmX_trans = (-grid_pix_trans(:,1) + lsr.refPxl(1)) / lsr.pxlPerMM;
grid_mmY_trans = (-grid_pix_trans(:,2) + lsr.refPxl(2)) / lsr.pxlPerMM;

lsr.grid = [grid_mmX_trans, grid_mmY_trans];
lsr.locationSet = num2cell(1:size(lsr.grid,1));
lsr             = computeOuputData(lsr);


axes(obj.camfig);
end