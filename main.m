clear;
clc;

SensorMacros = SetEnabledSensorsMacrosClass;

shimmer1 = ShimmerHandleClass("Shimmer3-7188");

if (shimmer1.connect)
    disp("Successfully connected to " + shimmer1.name);
else
    disp("Failed to connect to " + shimmer1.name);
end

if (shimmer1.disableAllSensors)
    disp(shimmer1.name + " sensors disabled");
end

if (shimmer1.setEnabledSensors(SensorMacros.ACCEL,1))
    disp("Enabled specified sensors on " + shimmer1.name);
end

if (shimmer1.startStreaming)
    disp(shimmer1.name + " started streaming");
end

pause(5);

if (shimmer1.stopStreaming)
    disp(shimmer1.name + " stopped streaming");
end