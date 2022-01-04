function click_frametoexcl_display(Perim,frametoexcl,win_posi,options)

    % OPTIONS:
% options.startPosi: Start position to display. Default : 1;
% options.threshold: Upper and lower threshold to automatically exclude frames. [min max]. default is [0 1200];
% options.windowSize: Number of frame per window. Default : 50

% DEFAULT VALUES
% startPosi = 1;
% thresh = [0 1200];
windowSize = 50;

% =========================================================================
% SOME CHECKUPS

if nargin > 3
%     if isfield(options,'startPosi'); startPosi = options.startPosi; end
%     if isfield(options,'threshold'); thresh = options.threshold; end
    if isfield(options,'windowSize'); windowSize = options.windowSize; end

end
% =========================================================================

% Define graph params
maxA = max(Perim); % to set ylim
if maxA > 800
    maxA = 800;
end
minA = 200; % to set ylim NEED IMPROVEMENT
lA = length(Perim); % to set maximum value of window
nXL = ceil(lA/windowSize);
XL(:,1) = (0:nXL-1)*windowSize;
XL(:,2) = (1:nXL)*windowSize;

current_XL = XL(win_posi,:);
i_ftl = find(frametoexcl >= current_XL(1) & frametoexcl <= current_XL(2));
% Display graph
plot(Perim);
hold on; 
plot(frametoexcl(:),Perim(frametoexcl(:)),'rx');
for i = 1:length(i_ftl)
    plot([frametoexcl(i_ftl(i)) frametoexcl(i_ftl(i))],[0 maxA],':r');
end
hold off;

% Adjust graph params
xlim(XL(win_posi,:)); % Set xlim to the current window
ylim([0 maxA+100])
text(XL(win_posi,1)+1,maxA+40,'Press ESC when done.');
text(XL(win_posi,1)+1,maxA+20,'D: next window')
text(XL(win_posi,1)+1,maxA+0,'S: previouswindow')
text(XL(win_posi,1)+1,maxA-20,'Right-click: delete','color','r')
xlabel('Frame #')
ylabel('Diameter')


