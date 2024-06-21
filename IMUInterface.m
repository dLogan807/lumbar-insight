classdef IMUInterface < handle
    %IMUINTERFACE Abstract class for creating an IMU object
    
    properties (SetAccess = protected, GetAccess = protected)
        DeviceName
        LatestQuaternion
    end
    
    methods (Abstract)
        connect(deviceName)
        % Connect to a device using its Bluetooth name

        disconnect
        % Disconnect from the device

        configure
        % Configure the device

        startSession
        % Start streaming data

        endSession
        % Stop streaming data

        retrieveLatestQuaternion
        % Get the most recent quaternion

    end
end

