classdef (Abstract) IMUInterface < handle
    %IMUINTERFACE Abstract class for creating an IMU object
    
    properties (SetAccess = protected)
        Name
    end

    properties (SetAccess = private)
        IsConnected
        IsStreaming
    end
    
    methods
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

        getLatestQuaternion(obj)
        % Get the most recent quaternion and update the property
    end
end

