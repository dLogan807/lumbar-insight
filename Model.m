classdef Model < handle
    %MODEL Application data model.
    
    properties
        % Application data.

        IMUDevices (1, 2) IMUInterface = [ShimmerIMU("temp"), ShimmerIMU("temp")]
        BluetoothDevices table

        Cameras (1, :) Camera

        LatestAngle double
        SmallestAngle double = -1
        LargestAngle double = -1

        FullFlexionAngle double
        StandingAngle double
        ThresholdAnglePercentage uint8 = 0.8
        timeAboveThresholdAngle = 0

        SessionInProgress logical = false
    end
    
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

        function latestAngle = get.LatestAngle( obj )
            quaternion1 = obj.IMUDevices(1).LatestQuaternion;
            quaternion2 = obj.IMUDevices(2).LatestQuaternion;

            latestAngle = calculateAngle(obj, quaternion1, quaternion2);
        end

        function set.ThresholdAnglePercentage( obj, thresholdPercentage )
            obj.ThresholdAnglePercentage = double(thresholdPercentage) * 0.01;
        end

        function connected = connectDevice( obj, deviceName, deviceType, deviceIndex )
            % CONNECTDEVICE Attempt device connection, notify controller,
            % and configure device

            connected = false;

            if (deviceType == DeviceTypes.Shimmer)
                obj.IMUDevices(deviceIndex) = ShimmerIMU(deviceName);
                connected = obj.IMUDevices(deviceIndex).connect;
            else
                disp("Device of type " + string(deviceType) + " is not implemented.");
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
            obj.IMUDevices(1).startStreaming;
            obj.IMUDevices(2).startStreaming;

            quaternion1 = obj.IMUDevices(1).LatestQuaternion;
            quaternion2 = obj.IMUDevices(2).LatestQuaternion;

            quat3dDifference = getQuat3dDifference( obj, quaternion1, quaternion2 );
            obj.StandingAngle = calculateAngle(obj, quat3dDifference);

            notify( obj, "StandingAngleCalibrated" )
        end

        function calibrateFullFlexionAngle( obj )
            obj.IMUDevices(1).startStreaming;
            obj.IMUDevices(2).startStreaming;

            quaternion1 = obj.IMUDevices(1).LatestQuaternion;
            quaternion2 = obj.IMUDevices(2).LatestQuaternion;

            quat3dDifference = getQuat3dDifference( obj, quaternion1, quaternion2 );
            obj.FullFlexionAngle = calculateAngle(obj, quat3dDifference);

            notify( obj, "FullFlexionAngleCalibrated")
        end

    end % methods

    methods (Access = private)
        function angle = calculateAngle( ~, quat3dDifference)
            % CALCULATEANGLE Calculate the angle between two quaternions
            % https://au.mathworks.com/matlabcentral/answers/415936-angle-between-2-quaternions?s_tid=answers_rc1-2_p2_MLT
    
            angle = 2*acosd(quat3dDifference(1));
        end % calculateAngle

        function angle = calculateAngleRelatively( obj, quat3dDifference)
            % CALCULATEANGLE Calculate the angle between two quaternions
            % https://au.mathworks.com/matlabcentral/answers/415936-angle-between-2-quaternions?s_tid=answers_rc1-2_p2_MLT
    
            angle = 2*acosd(quat3dDifference(1));

            if (isNegativeAngle( obj, quat3dDifference ))
                angle = angle * -1;
            end
        end % calculateAngle

        function quat3dDifference = getQuat3dDifference( ~, quaternion1, quaternion2 )
            quat3dDifference = quatmultiply(quatconj(quaternion1), quaternion2);
        end

        function isNegative = isNegativeAngle( ~, quat3dDiffernce )
            %https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles
            % roll (x-axis rotation)

            w = quat3dDiffernce(1);
            x = quat3dDiffernce(2);
            y = quat3dDiffernce(3);
            z = quat3dDiffernce(4);
            
            sinr_cosp = 2 * (w * x + y * z);
            cosr_cosp = 1 - 2 * (x * x + y * y);
            roll = atan2(sinr_cosp, cosr_cosp);
        
            % pitch (y-axis rotation)
            sinp = sqrt(1 + 2 * (w * y - x * z));
            cosp = sqrt(1 - 2 * (w * y - x * z));
            pitch = 2 * atan2(sinp, cosp) - pi / 2;
        
            % yaw (z-axis rotation)
            siny_cosp = 2 * (w * z + x * y);
            cosy_cosp = 1 - 2 * (y * y + z * z);
            yaw = atan2(siny_cosp, cosy_cosp);

            if (roll < 0)
                isNegative = true;
            else
                isNegative = false;
            end
                
        end

        function startStreaming( obj ) 
        
            obj.IMUDevices(1).startStreaming;
            obj.IMUDevices(2).startStreaming;

        end % startStreaming

        function stopStreaming( obj ) 
        
            obj.IMUDevices(1).stopStreaming;
            obj.IMUDevices(2).stopStreaming;

        end % stopStreaming
    end

end % classdef