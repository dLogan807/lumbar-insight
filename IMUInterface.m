classdef (Abstract) IMUInterface < handle
    %IMUINTERFACE Abstract class for creating an IMU object
    
    properties (Abstract, SetAccess = protected)
        Name
        IsConnected
        IsStreaming
        LatestQuaternion
    end
    
    methods (Abstract)
        connect(obj)
        % Connect to a device using its name

        disconnect(obj)
        % Disconnect from the device

        configure(obj)
        % Configure the device

        startSession(obj)
        % Start streaming data

        endSession(obj)
        % Stop streaming data
    end
end

