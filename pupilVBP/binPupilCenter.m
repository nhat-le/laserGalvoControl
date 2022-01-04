function I = binPupilCenter(C,nX,nY)
% function I = binPupilCenter(C,nX,nY)
% Take center (C) and bin it to an image (I). C has to be in pixels.

if nargin < 3
    nY = 256;
    if nargin < 2
        nX = 256;
    end
end

I = zeros(nX,nY);
C = round(C);
for x = 1:nX
    for y = 1:nY
         I(x,y) = sum(C(:,2) == x & C(:,1) == y);
    end
end
