load('C:\Users\MMM_3p1_SI\Documents\wftoolbox\templates\f29Template\atlas_f29.mat');

figure;
imagesc(borders);
hold on
set(gca,'YDir','normal','xtick',[],'ytick',[]);


% Frontal coords
title('select points for frontal');
frontal_coords = [];
for i = 1:10
    coords = ginput(1);
    plot(coords(1), coords(2), 'rx');
    frontal_coords(i,:) = coords;
end

title('select points for motor');
% Motor coords
motor_coords = [];
for i = 1:10
    coords = ginput(1);
    plot(coords(1), coords(2), 'rx');
    motor_coords(i,:) = coords;
end

% Visual coords
title('select points for visual');
visual_coords = [];
for i = 1:10
    coords = ginput(1);
    plot(coords(1), coords(2), 'rx');
    visual_coords(i,:) = coords;
end


% RSC coords
title('select points for RSC');
rsc_coords = [];
for i = 1:10
    coords = ginput(1);
    plot(coords(1), coords(2), 'rx');
    rsc_coords(i,:) = coords;
end

close all

%% Visualize selected points
figure;
imagesc(borders)
hold on
plot(frontal_coords(:,1), frontal_coords(:,2), 'rx')
plot(motor_coords(:,1), motor_coords(:,2), 'bx')
plot(visual_coords(:,1), visual_coords(:,2), 'yx')
plot(rsc_coords(:,1), rsc_coords(:,2), 'gx')

%%
save('C:\Users\MMM_3p1_SI\Documents\wftoolbox\templates\f29Template\cluster_points.mat', 'motor_coords', 'visual_coords', 'frontal_coords', 'rsc_coords');
save('C:\Users\MMM_3p1_SI\Documents\wftoolbox\templates\f26Template\cluster_points.mat', 'motor_coords', 'visual_coords', 'frontal_coords', 'rsc_coords');
save('C:\Users\MMM_3p1_SI\Documents\wftoolbox\templates\f27Template\cluster_points.mat', 'motor_coords', 'visual_coords', 'frontal_coords', 'rsc_coords');
save('C:\Users\MMM_3p1_SI\Documents\wftoolbox\templates\f32Template\cluster_points.mat', 'motor_coords', 'visual_coords', 'frontal_coords', 'rsc_coords');

