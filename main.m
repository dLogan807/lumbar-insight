clear

shimmer1 = ShimmerClass("Shimmer3-5852")

if (shimmer1.connect)
    disp("Successfully connected to " + shimmer1.shimmerName)
else
    disp("Failed to connect to " + shimmer1.shimmerName)
end




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