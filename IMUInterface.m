classdef IMUInterface < handle
    %IMUINTERFACE Abstract class for creating an IMU object
    
    properties (Abstract, SetAccess = protected)
        Name string
        IsConnected logical
        IsStreaming logical
        LatestQuaternion
        BatteryInfo string
    end
    
    methods (Abstract)
        connect(obj)
        % Connect to a device using its name

        disconnect(obj)
        % Disconnect from the device

        configure(obj)
        % Configure the device

        startStreaming(obj)
        % Start streaming data

        stopStreaming(obj)
        % Stop streaming data
    end
end

