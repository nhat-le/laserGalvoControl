function Image = segmentPupilONLINE(Image,threshold,options)
% Function to segment image of pupil based on adaptive threshold.

% OPTIONS:
% options.showfig = 1   Display figure (1) or not (0). Default = 1;
% options.adaptive = 1  Use adaptive threshold (1) or not (0). Default = 1;

% DEFAULT VALUES
showfig = 1;
adaptive = 1;
convolution = 0;
% =========================================================================
% SOME CHECKUPS

if nargin > 2
    if isfield(options,'showfig'); showfig = options.showfig; end 
    if isfield(options,'adaptive'); adaptive = options.adaptive; end 
    if isfield(options,'conv'); convolution = options.conv; end 
end
   
%% Segment Image

% ---
if showfig == 1; 
    F = figure ;
    scrsz = get(groot,'ScreenSize');
    set(F,'Position',[150 scrsz(4)/4 scrsz(3)*4/5 scrsz(4)/2])
    nSub = 6;
end
% ---

if convolution > 0
    convMTX = ones(5)*0.001;%/5^2; % NOTE 0.2 is arbitrary and seems to work but has to be improved in future.
    Image = conv2(Image,convMTX,'same'); %if showfig == 1; figure(F);  subplot(1,nSub,1); imshow(Image); title('Conv'); end
end
% Image=~im2bw(Image,threshold); if showfig == 1; figure(F);  subplot(1,nSub,2); imshow(Image); title('im2bw'); end
if adaptive > 0
    Image = ~imbinarize(Image, 'adaptive','Sensitivity',threshold,'ForegroundPolarity','dark');
else
    Image = ~imbinarize(Image, threshold);
end
if showfig == 1; figure(F);  subplot(2,nSub,1); imshow(Image); title('im2bw'); end
Image=bwareaopen(Image,100); if showfig == 1; figure(F); subplot(2,nSub,2); imshow(Image); title('bwareaopen 100'); end
Image=bwmorph(Image,'close'); if showfig == 1; figure(F); subplot(2,nSub,3); imshow(Image); title('close'); end
Image=bwmorph(Image,'open'); %if showfig == 1; figure(F); subplot(1,nSub,4); imshow(Image); title('close II'); end
Image=bwareaopen(Image,200);if showfig == 1; figure(F); subplot(2,nSub,4); imshow(Image); title('bwareaopen 200'); end
Image=imfill(Image,'holes'); if showfig == 1; figure(F); subplot(2,nSub,5); imshow(Image); title('imfill holes'); end

