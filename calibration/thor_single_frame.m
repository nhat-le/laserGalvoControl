function Data = thor_single_frame(cam, MemId, Width, Height, Bits)
cam.Acquisition.Freeze(uc480.Defines.DeviceParameter.Wait);

[~,tmp] = cam.Memory.CopyToArray(MemId);

Data = reshape(uint8(tmp), [Bits/8, Width, Height]);
Data = Data(1:3, 1:Width, 1:Height);
Data = permute(Data, [3,2,1]);
