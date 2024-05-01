clear;
clc;

SensorMacros = SetEnabledSensorsMacrosClass;    

shimmer1 = ShimmerHandleClass("Shimmer3-5852");
shimmer2 = ShimmerHandleClass("Shimmer3-5847");

shimmer1.connect;
shimmer2.connect;

shimmer1.setsamplingrate(51.2);                                        % Set the shimmer sampling rate to 51.2Hz
shimmer2.setsamplingrate(51.2);
%shimmer.setinternalboard('9DOF');                                     % Set the shimmer internal daughter board to '9DOF'
shimmer1.disableAllSensors;                                            % disable all sensors
shimmer2.disableAllSensors;
shimmer1.setEnabledSensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,...  % Enable the gyroscope, magnetometer and accelerometer.
SensorMacros.ACCEL,1);
shimmer2.setEnabledSensors(SensorMacros.GYRO,1,SensorMacros.MAG,1, SensorMacros.ACCEL,1);
shimmer1.setaccelrange(0);                                             % Set the accelerometer range to 0 (+/- 1.5g for Shimmer2/2r, +/- 2.0g for Shimmer3)
shimmer2.setaccelrange(0);
%shimmer.setorientation3D(1);                                          % Enable orientation3D
%shimmer.setgyroinusecalibration(1);                                   % Enable gyro in-use calibration

%orientation3Dexample(shimmer1, shimmer2, 60, 'testdata.dat');