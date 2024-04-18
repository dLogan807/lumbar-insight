classdef ShimmerClass
    %Class to interface with a Shimmer3 device
    
    properties (Constant)
        %See the BtStream for Shimmer Firmware User Manual for more
        commandIdentifiers = struct("INQUIRY_COMMAND",0x01,"SET_SENSORS_COMMAND",0x08, "START_STREAMING_COMMAND", 0x07, "STOP_STREAMING_COMMAND", 0x20);
    end

    properties
        shimmerName;
        shimmerDevice;
    end
    
    methods
        %Constructor
        function thisShimmer = ShimmerClass(name)
            arguments 
                name (1,:) {string};
            end

            thisShimmer.shimmerName = name;
        end
        
        %Connect to the Shimmer
        function isConnected = connect(thisShimmer)
            try
                bluetooth(thisShimmer.shimmerName);
            catch
                isConnected = false;
                warning('Could not connect to ' + thisShimmer.shimmerName);
                return
            end

            isConnected = true;
        end

        %Disable all sensors
        function areDisabled = disableSensors(thisShimmer)
            areDisabled = false;
        end
            
    end
end

