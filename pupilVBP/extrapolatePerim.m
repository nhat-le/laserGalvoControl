function PerimOut = extrapolatePerim(PerimIn,frameID,showplot)
% Linear extrapolation of Perim values for excluded frames contained in
% frameID

if nargin < 3
    showplot = 1;
end

i = 1;
nPup = length(PerimIn);
PerimOut = PerimIn;
while i <= nPup
    if any(i == frameID(:))
        if i == 1; %Case in which frame to excl is the first frame.
            Pa(2) = i;
            while any(i == frameID(:))
                i = i+1;
            end
            Pb(1) = PerimIn(i);
            Pb(2) = i;
            PerimOut(Pa(2):Pb(2)) = ones(length(Pa(2):Pb(2)),1)*Pb(1);
        else
            Pa(1) = PerimIn(i-1);
            Pa(2) = i-1;
            while any(i == frameID(:))
                i = i+1;
            end
            if i <= nPup
                Pb(1) = PerimIn(i);
            else % Case in which frame to excl is the last frame.
                Pb(1) = Pa(1);
            end
            Pb(2) = i;
            extrap = linspace(Pa(1),Pb(1),Pb(2)-Pa(2)+1);
            PerimOut(Pa(2)+1:Pb(2)-1) = extrap(2:end-1);
        end
    end
    i = i+1;
    
end

if showplot == 1
    figure;
    hold on;
    plot(PerimIn); plot(PerimOut,'r');
    legend('Before','After extrapolate');
    box off; set(gca,'tickdir','out');
    hold off;
end
