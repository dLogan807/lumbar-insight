classdef (Abstract) IMUInterface < handle
    %IMUINTERFACE Abstract class for creating an IMU object
    
    properties (SetAccess = protected, GetAccess = protected)
        DeviceName
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

