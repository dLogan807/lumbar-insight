classdef IMUInterface < handle
    %Abstract class for creating an IMU
    
    properties (Abstract, SetAccess = protected)
        Name string
        IsConfigured logical
        BatteryInfo string
        SamplingRates (1, :) double
        SamplingRate double
    end

    properties (Abstract, SetAccess = protected, Dependent)
        LatestQuaternion (1, 4) double
        IsConnected logical
        IsStreaming logical
    end
    
    methods (Abstract)
        connect(obj)
        % Connect to a device using its name

        disconnect(obj)
        % Disconnect from the device

        configure(obj, samplingRate)
        % Configure the device

        startStreaming(obj)
        % Start streaming data

        stopStreaming(obj)
        % Stop streaming data
    end
end

