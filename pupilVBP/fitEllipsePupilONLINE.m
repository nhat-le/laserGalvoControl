function [Elp,Cent,Rad,Perim] = fitEllipsePupilONLINE(Image)
%% Fit ellipse.......................................................... 
[B,~] = bwboundaries(Image,'noholes');

if length(B) > 1
    for j = 1:length(B)
        z(j) = size(B{j},1);
    end;
    [~, ind] = max(z);
else
    ind = 1;
end;

try
    try
        boundary = B{ind};
        X1 = boundary(:,2);
        X2 = boundary(:,1);
        T = [X1,X2];
        T = T';
        [z, a, b, alpha] = fitellipse(T,'linear');
    catch 
        z(ind) = 0;
        [~, ind] = max(z);
        boundary = B{ind};
        X1 = boundary(:,2);
        X2 = boundary(:,1);
        T = [X1,X2];
        T = T';
        [z, a, b, alpha] = fitellipse(T,'linear');
    end;
catch
    z = zeros(2,1);
    a = 0;
    b = 0;
    alpha = 0;
end

Elp.z = z;
Elp.a = a;
Elp.b = b;
Elp.alpha = alpha;
Cent = z;
Rad.a = a;
Rad.b = b;
Perim = pi*( 3*(a+b) - sqrt( (3*a+b)*(a+3*b) ) );

