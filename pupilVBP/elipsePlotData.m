function X = elipsePlotData(Elp)
% function X = elipsePlotData(Elp)
% a = Elp.a;
% b = Elp.b;
% z = Elp.z;
% alpha = Elp.alpha;

% Parameters
a = Elp.a;
b = Elp.b;
z = Elp.z;
alpha = Elp.alpha;
npts = 100;
t = linspace(0, 2*pi, npts);
% Rotation matrix
Q = [cos(alpha), -sin(alpha); sin(alpha) cos(alpha)];
% Ellipse points
X = Q * [a * cos(t); b * sin(t)] + repmat(z, 1, npts);
