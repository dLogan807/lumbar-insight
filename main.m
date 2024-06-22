clear;
clc;

shimmer1 = ShimmerDriver("Shimmer3-719E");
shimmer2 = ShimmerDriver("Shimmer3-5852");
captureDuration = 120;

orientation3D(shimmer1, shimmer2, captureDuration);