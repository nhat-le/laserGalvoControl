s = daq.createSession('ni');
s.addAnalogOutputChannel('Dev1', 0:1, 'Voltage');

%%
s.outputSingleScan([-0.2 0.5]);