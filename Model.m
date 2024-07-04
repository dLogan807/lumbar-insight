classdef Model < handle
    %MODEL Application data model.
    
    properties
        % Application data.

        IMUDevices (1, 2) IMUInterface = [ShimmerIMU("temp"), ShimmerIMU("temp")]
        BluetoothDevices table

        Cameras (1, :) Camera

        CurrentAngle double
        FullFlexionAngle double
        StandingAngle double
    end % properties ( SetAccess = private )
    
    events ( NotifyAccess = private )
        % Events broadcast when the model is altered.
        DeviceListUpdated

        DevicesConnectedChanged

        StandingAngleCalibrated
        FullFlexionAngleCalibrated

        SessionStarted
        SessionEnded

    end % events ( NotifyAccess = private )
    
    methods

        function set.BluetoothDevices( obj, deviceList )
            % SET.BLUETOOTHDEVICES Set table of bluetooth devices, notify
            % controller

            obj.BluetoothDevices = deviceList;

            notify( obj, "DeviceListUpdated" )
        end

        function connectDevice( obj, deviceName, deviceType, deviceIndex )
            % CONNECTDEVICE Attempt device connection, notify controller,
            % and configure device

            connected = false;

            if (deviceType == DeviceTypes.Shimmer)
                obj.IMUDevices(deviceIndex) = ShimmerIMU(deviceName);
                connected = obj.IMUDevices(deviceIndex).connect;
            else
                disp("Device of type " + string(deviceType) + " is not implemented.");
            end

            if (connected)
                obj.IMUDevices(deviceIndex).configure;
                obj.IMUDevices(deviceIndex).startStreaming;
            end

            notify( obj, "DevicesConnectedChanged" )

        end % connectDevice

        function disconnectDevice( obj, deviceIndex )
            % DISCONNECTDEVICE Disconnect a device

            obj.IMUDevices(deviceIndex).disconnect;

            notify( obj, "DevicesConnectedChanged" )

        end % disconnectDevice

        function devicesConnected = twoIMUDevicesConnected( obj )
            devicesConnected = (obj.IMUDevices(1).IsConnected && obj.IMUDevices(2).IsConnected);
        end

        function batteryInfo = getBatteryInfo( obj, deviceIndex )
            % GETBATTERYINFO Get battery information of the IMU
            batteryInfo = obj.IMUDevices(deviceIndex).BatteryInfo;
        end

        function calibrateStandingAngle( obj )
            quaternion1 = obj.IMUDevices(1).LatestQuaternion;
            quaternion2 = obj.IMUDevices(2).LatestQuaternion;

            obj.StandingAngle = calculateAngle(obj, quaternion1, quaternion2);

            notify( obj, "StandingAngleCalibrated" )
        end

        function calibrateFullFlexionAngle( obj )
            quaternion1 = obj.IMUDevices(1).LatestQuaternion;
            quaternion2 = obj.IMUDevices(2).LatestQuaternion;

            obj.FullFlexionAngle = calculateAngle(obj, quaternion1, quaternion2);

            notify( obj, "FullFlexionAngleCalibrated")
        end
        
    end % methods

    methods (Access = private)
        function startStreaming( obj ) 
        
            obj.IMUDevices(1).startStreaming;
            obj.IMUDevices(2).startStreaming;

        end % startSession

        function endSession( obj ) 
        
            obj.IMUDevices(1).stopStreaming;
            obj.IMUDevices(2).stopStreaming;

        end % endSession

        function angle = calculateAngle( obj, quaternion1, quaternion2)
            % CALCULATEANGLE Calculate the angle between two quaternions
            % https://au.mathworks.com/matlabcentral/answers/415936-angle-between-2-quaternions?s_tid=answers_rc1-2_p2_MLT
            
            z = quatmultiply(quatconj(quaternion1), quaternion2);
    
            angle = 2*acosd(z(1));
        end % calculateAngle
    end

end % classdef