clear;

SensorMacros = SetEnabledSensorsMacrosClass;

%shimmer1 = ShimmerHandleClass("Shimmer3-5852");
%shimmer2 = ShimmerHandleClass("Shimmer3-7188");
shimmer3 = ShimmerHandleClass("Shimmer3-5847");

%shimmer1.connect;
%shimmer2.connect;
shimmer3.connect;

orientation3Dexample(shimmer3, 60, 'testdata.dat');