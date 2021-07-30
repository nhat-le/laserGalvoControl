NET.addAssembly('C:\Program Files\Thorlabs\Scientific Imaging\DCx Camera Support\Develop\DotNet\uc480DotNet.dll');
cam = uc480.Camera;

cam.Init(0);

cam.Display.Mode.Set(uc480.Defines.DisplayMode.DiB);
cam.PixelFormat.Set(uc480.Defines.ColorMode.RGB8Packed);
cam.Trigger.Set(uc480.Defines.TriggerMode.Software);

figure;
[status,MemId] = cam.Memory.Allocate(true);
disp(status);

[~,Width,Height,Bits,~] = cam.Memory.Inquire(MemId);
for i = 1:100
    
%     cam.Acquisition.Capture
    cam.Acquisition.Freeze(uc480.Defines.DeviceParameter.Wait);

    [~,tmp] = cam.Memory.CopyToArray(MemId);

    Data = reshape(uint8(tmp), [Bits/8, Width, Height]);
    Data = Data(1:3, 1:Width, 1:Height);
    Data = permute(Data, [3,2,1]);

    imshow(Data);
end