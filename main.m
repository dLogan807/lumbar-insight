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

if (shimmer1.setEnabledSensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,SensorMacros.ACCEL,1))
    disp("Enabled specified sensors on " + shimmer1.name);
end

if (shimmer1.startStreaming)
    disp(shimmer1.name + " started streaming");
end

pause(10)
read(shimmer1.bluetoothConn, 50)

if (shimmer1.stopStreaming)
    disp(shimmer1.name + " stopped streaming");
end