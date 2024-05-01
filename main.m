clear;
clc;

shimmer1 = ShimmerHandleClass("Shimmer3-5852");
shimmer2 = ShimmerHandleClass("Shimmer3-5847");

shimmer1.connect;
shimmer2.connect;

shimmer1.determinehwcompcode;
disp(shimmer1.name + " HW Comp Code: " + shimmer1.HardwareCompatibilityCode);
shimmer2.determinehwcompcode;
disp(shimmer2.name + " HW Comp Code: " + shimmer2.HardwareCompatibilityCode);

%orientation3Dexample(shimmer1, shimmer2, 60, 'testdata.dat');