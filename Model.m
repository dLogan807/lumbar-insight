classdef Model < handle
    %MODEL Application data model.
    
    properties
        % Application data.

        IMUDevices (1, 2) IMUInterface = [ShimmerIMU("placeholder1"), ShimmerIMU("placeholder2")]
        BluetoothDevices table

        Cameras (1, :) Camera

        LatestAngle double
        SmallestAngle double = -1
        LargestAngle double = -1

        FullFlexionAngle double
        StandingAngle double
        ThresholdAnglePercentage uint8 = 0.8
        timeAboveThresholdAngle = 0
    end

    properties (SetAccess = private)
        SessionInProgress logical = false
        OperationInProgress logical = false
    end
    
    events ( NotifyAccess = private )
        % Events broadcast when the model is altered.
        DeviceListUpdated

        DevicesConnectedChanged
        DevicesConfiguredChanged

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

            quat3dDifference = getQuat3dDifference( obj, quaternion1, quaternion2 );
            latestAngle = calculateAngle(obj, quat3dDifference);
        end

        function set.ThresholdAnglePercentage( obj, thresholdPercentage )
            obj.ThresholdAnglePercentage = double(thresholdPercentage) * 0.01;
        end

        function connected = connectDevice( obj, deviceName, deviceType, deviceIndex )
            % CONNECTDEVICE Attempt device connection, notify controller,
            % and configure device

            connected = false;
            if ( obj.OperationInProgress )
                return
            end
            operationStarted;

            if (deviceType == DeviceTypes.Shimmer)
                obj.IMUDevices(deviceIndex) = ShimmerIMU(deviceName);
                connected = obj.IMUDevices(deviceIndex).connect;
            else
                disp("Device of type " + string(deviceType) + " is not implemented.");
            end

            operationCompleted;

            notify( obj, "DevicesConnectedChanged" )

        end % connectDevice

        function disconnected = disconnectDevice( obj, deviceIndex )
            % DISCONNECTDEVICE Disconnect a device

            disconnected = false;
            if ( obj.OperationInProgress )
                return
            end
            operationStarted;

            disconnected = obj.IMUDevices(deviceIndex).disconnect;

            operationCompleted;

            notify( obj, "DevicesConnectedChanged" )

        end % disconnectDevice

        function devicesConnected = bothIMUDevicesConnected( obj )
            devicesConnected = (obj.IMUDevices(1).IsConnected && obj.IMUDevices(2).IsConnected);
        end

        function devicesConfigured = bothIMUDevicesConfigured( obj )
            devicesConfigured = (obj.IMUDevices(1).IsConfigured && obj.IMUDevices(2).IsConfigured);
        end

        function batteryInfo = getBatteryInfo( obj, deviceIndex )
            % GETBATTERYINFO Get battery information of the IMU

            if ( obj.OperationInProgress )
                return
            end
            operationStarted;

            batteryInfo = obj.IMUDevices(deviceIndex).BatteryInfo;

            operationCompleted;
        end

        function configured = configure( obj, deviceIndex, samplingRate )
            %CONFIGURE Configure the IMU with the specified sampling rate

            configured = false;
            if ( obj.OperationInProgress )
                return
            end
            operationStarted;

            device = obj.IMUDevices(deviceIndex);

            configured = device.configure(samplingRate);

            operationCompleted;

            notify( obj, "DevicesConfiguredChanged" )
        end

        function samplingRate = lowestSamplingRate( obj )
            %LOWESTSAMPLINGRATE Retrieve the lowest sampling rate of the
            %IMUs

            samplingRate = -1;

            if (obj.IMUDevices(1).IsConfigured)
                samplingRate = obj.IMUDevices(1).SamplingRate;
            end

            device2Rate = obj.IMUDevices(2).SamplingRate;
            if (obj.IMUDevices(2).IsConfigured && (device2Rate < samplingRate))
                samplingRate = device2Rate;
            end
        end

        function calibrated = calibrateStandingAngle( obj )
            %CALIBRATESTANDINGANGLE Calibrate the subject's standing angle

            if (obj.OperationInProgress)
                return
            end
            operationStarted;

            startStreamingBoth( obj );
            calibrated = true;
            try
                obj.StandingAngle = obj.LatestAngle;
            catch ME
                calibrated = false;
                warning(ME);
            end

            operationCompleted;
            if (calibrated)
                notify( obj, "StandingAngleCalibrated" )
            end
        end

        function calibrated = calibrateFullFlexionAngle( obj )
            %CALIBRATEFULLFLEIONANGLE Calibrate the subject's full fleion
            %angle

            if (obj.OperationInProgress)
                return
            end
            operationStarted;

            startStreamingBoth( obj );
            calibrated = true;
            try
                obj.FullFlexionAngle = obj.LatestAngle;
            catch ME
                calibrated = false;
                warning(ME);
            end

            operationCompleted;
            if (calibrated)
                notify( obj, "FullFlexionAngleCalibrated" )
            end
        end

        function startStreamingBoth( obj )
            %STARTSTREAMINGBOTH Start streaming on both devices, if
            %possible

            device1 = obj.IMUDevices(1);
            device2 = obj.IMUDevices(2);

            if (device1.IsConnected && ~device1.IsStreaming)
                device1.startStreaming;
            end

            if (device2.IsConnected && ~device2.IsStreaming)
                device2.startStreaming;
            end

            % Wait for data
            pause(2);
        end

        function stopStreamingBoth( obj )
            %STOPSTREAMINGBOTH Stop streaming on both devices

            device1 = obj.IMUDevices(1);
            device2 = obj.IMUDevices(2);

            if (device1.IsConnected && device1.IsStreaming)
                device1.stopStreaming;
            end

            if (device2.IsConnected && device2.IsStreaming)
                device2.stopStreaming;
            end
        end

        function startSession( obj ) 
        
            startStreamingBoth( obj );

            obj.SessionInProgress = true;

        end % startStreaming

        function stopSession( obj ) 
        
            stopStreamingBoth( obj );

            obj.SessionInProgress = false;

        end % stopStreaming

    end % methods

    methods (Access = private)
        function operationStarted( obj )
            obj.OperationInProgress = true;
        end

        function operationCompleted( obj )
            obj.OperationInProgress = false;
        end

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

    end

end % classdef