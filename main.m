clear;
clc;

SensorMacros = SetEnabledSensorsMacrosClass;

shimmer1 = ShimmerHandleClass("Shimmer3-5852");

if (shimmer1.connect)
    disp("Successfully connected to " + shimmer1.name);
else
    disp("Failed to connect to " + shimmer1.name);
end

if (shimmer1.disableAllSensors)
    disp(shimmer1.name + " sensors disabled");
end

read(shimmer1.bluetoothConn,1)

if (shimmer1.setEnabledSensors(SensorMacros.ACCEL,1))
    disp("Enabled specified sensors on " + shimmer1.name);
end

read(shimmer1.bluetoothConn,1)

% pause(10);
% 
% if (shimmer1.startStreaming)
%     disp(shimmer1.name + " started streaming");
% end
% 
% read(shimmer1.bluetoothConn,200)
% pause(10);
% 
% if (shimmer1.stopStreaming)
%     disp(shimmer1.name + " stopped streaming");
%     flush(shimmer1.bluetoothConn, "input");
% end

% pause(10);
% 
% read(shimmer1.bluetoothConn,2)

% shimmer1 = bluetooth("Shimmer3-5852")
% shimmer2 = bluetooth("Shimmer3-5847")
% 
% INQUIRY_COMMAND = 0x01
% 
% write(shimmer1, INQUIRY_COMMAND)
% 
% read(shimmer1,20)
% 
% write(shimmer2, INQUIRY_COMMAND)
% 
% read(shimmer2,20)