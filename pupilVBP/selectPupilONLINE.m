function Image = selectPupilONLINE(Image)

%% Select closest region to center of image
[H,W,~] = size(Image);
r = round(H/2);
c = round(W/2);

s = regionprops(Image,'centroid');
centroids = cat(1, s.Centroid);
fun = @(x,y) sqrt((x-c).^2+(y-r).^2); % Function to calculate distance between center and regions
if ~isempty(centroids)
    x = centroids(:,1);
    y = centroids(:,2);
    D = bsxfun(fun,x,y); % Distance between center and regions
    [~,i] = min(D);
    Image = bwlabel(Image);
    Image(Image ~= i) = 0;
    Image(Image == i) = 1;
end

