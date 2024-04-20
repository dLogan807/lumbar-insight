clear;
clc;

SensorMacros = SetEnabledSensorsMacrosClass;

shimmer1 = ShimmerHandleClass("Shimmer3-5852");

if (shimmer1.connect)
    disp("Successfully connected to " + shimmer1.name);
else
    disp("Failed to connect to " + shimmer1.name);
end

shimmer1.disableAllSensors;

shimmer1.setEnabledSensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,SensorMacros.ACCEL,1);

shimmer1.startStreaming;

waitfor(3);

shimmer1.stopStreaming;



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