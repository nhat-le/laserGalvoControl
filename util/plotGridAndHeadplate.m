function plotGridAndHeadplate(fh)

% plotGridAndHeadplate(fh)
% plot both grid and headplate reference on axis fh

%% initialize / focus
global obj lsr

if nargin < 1; fh = []; end

if isempty(fh)
  axes(obj.camfig); % focus
end

cla

%% image
set(gca,'XDir','normal', 'YDir','normal', 'xtick',[],'ytick',[]);

imagesc(obj.camData); 
colormap gray; 
axis image; 
hold on
view([90 -90])
caxis([lsr.disp_min, lsr.disp_max]);
set(gca,'XDir','reverse','xtick',[],'ytick',[]);
% set(gca,'xtick',[],'ytick',[]);

%% bregma
x = lsr.refPxl(1); y = lsr.refPxl(2);
plot(x,y,'m+','markersize',10) % reference

% headplate
if ~isempty(lsr.headplateOutline) && get(obj.headplate_toggle, 'Value')
  plot(lsr.headplateOutlineX,lsr.headplateOutlineY,'y.')
end

% allen borders
if ~isempty(lsr.borders) && get(obj.allen_toggle, 'Value')
  plot(lsr.bordersOutlineX,lsr.bordersOutlineY,'r.')
end

%% galvo locations
cl = {'y','b','r','c','g','m','w','k',[.2 .2 .2],[.4 .4 .4],[.6 .6 .6],[.8 .8 .8],...
  [1 .2 .2],[1 .4 .4],[1 .6 .6],[1 .8 .8],[.2 1 .2],[.4 1 .4],[.6 1 .6],[.8 1 .8],...
  [.2 .2 1],[.4 .4 1],[.6 .6 1],[.8 .8 1],[1 .2 0],[1 .4 0],[1 .6 0],[1 .8 0],...
  [0 1 .2],[0 1 .4],[0 1 .6],[0 1 .8],[1 0 .2],[1 0 .4],[1 0 .6],[1 0 .8],...
  [.2 0 1],[.4 0 1],[.6 0 1],[.8 0 1]};

if iscell(lsr.grid)
  for ii = 1:length(lsr.grid)
    for jj = 1:size(lsr.grid{ii},1)
      plot(lsr.gridImX{ii}{jj},lsr.gridImY{ii}{jj},'o','color',cl{ii})
      if jj == 1; text(lsr.gridImX{ii}{jj},lsr.gridImY{ii}{jj},num2str(ii),'color',cl{ii}); end
    end
  end
else
  % Update the imx and imy arrays...
  % generate grid location markers
%     lsr.gridImX = cell(1,length(lsr.grid));
%     lsr.gridImY = cell(1,length(lsr.grid));
    for ii = 1:size(lsr.grid,1)
        lsr.gridImX{ii}  = round(lsr.pxlPerMM*-lsr.grid(ii,1)) + lsr.refPxl(1);
        lsr.gridImY{ii}  = round(lsr.pxlPerMM*-lsr.grid(ii,2)) + lsr.refPxl(2);
        % go from ref. map to current image
        if ~isempty(lsr.imTform)
            [lsr.gridImX{ii},lsr.gridImY{ii}] = transformPointsInverse(lsr.imTform, lsr.gridImX{ii}, lsr.gridImY{ii});
        end        
%     
        text(lsr.gridImX{ii},lsr.gridImY{ii},num2str(ii),'color',cl{1},'horizontalAlignment','center')
    end
end


end
