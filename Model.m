classdef Model < handle
    %MODEL Application data model.
    
    properties
        % Application data.

        IMUDevices (1, 2) IMUInterface = [ShimmerIMU("placeholder1"), ShimmerIMU("placeholder2")]

        Cameras (1, :) Camera

        LatestAngle double
        LatestCalibratedAngle double
        SmallestAngle double = [];
        LargestAngle double = [];

        FullFlexionAngle double = []
        StandingOffsetAngle double = []
        ThresholdAnglePercentage uint8
        timeAboveThresholdAngle double = 0
    end

    properties (SetAccess = private)
        SessionInProgress logical = false
        OperationInProgress logical = false
    end
    
    events ( NotifyAccess = private )
        % Events broadcast when the model is altered.
        OperationStarted
        OperationCompleted

        DevicesConnectedChanged
        DevicesConfiguredChanged

        StandingOffsetAngleCalibrated
        FullFlexionAngleCalibrated

        SessionStarted
        SessionEnded

    end % events ( NotifyAccess = private )

    methods

        function latestAngle = get.LatestAngle( obj )
            %LATESTREANGLE Update and store the latest angle between the
            %IMUs, relative to subject's standing angle.

            quat3dDifference = getQuat3dDifference( obj );
            latestAngle = calculateAngle(obj, quat3dDifference);
        end

        function latestCalibratedAngle = get.LatestCalibratedAngle( obj )
            %GET.LATESTCALIBRATEDANGLE Get the latest angle zeroed to the
            %subject's standing position.

            if (isempty(obj.StandingOffsetAngle))
                warning("LatestCalibratedAngle: Standing offset angle not calibrated!");
            end

            latestCalibratedAngle = obj.LatestAngle + obj.StandingOffsetAngle;
        end

        function set.ThresholdAnglePercentage( obj, thresholdPercentage )

            arguments
                obj 
                thresholdPercentage int8
            end

            obj.ThresholdAnglePercentage = double(thresholdPercentage) * 0.01;
        end

        function connected = connectDevice( obj, deviceName, deviceType, deviceIndex )
            % CONNECTDEVICE Attempt device connection, notify controller,
            % and configure device
            
            arguments
                obj 
                deviceName string
                deviceType DeviceTypes
                deviceIndex int8
            end

            connected = false;
            if ( obj.OperationInProgress )
                return
            end
            operationStarted( obj );

            if (deviceType == DeviceTypes.Shimmer)
                obj.IMUDevices(deviceIndex) = ShimmerIMU(deviceName);
                connected = obj.IMUDevices(deviceIndex).connect;
            else
                disp("Device of type " + string(deviceType) + " is not implemented.");
            end

            operationCompleted( obj );

            %Reset angle calibration
            obj.FullFlexionAngle = [];
            obj.StandingOffsetAngle = [];
            notify( obj, "DevicesConnectedChanged" )

        end % connectDevice

        function disconnected = disconnectDevice( obj, deviceIndex )
            % DISCONNECTDEVICE Disconnect a device

            disconnected = false;
            if ( obj.OperationInProgress )
                return
            end
            operationStarted( obj );

            disconnected = obj.IMUDevices(deviceIndex).disconnect;

            operationCompleted( obj );

            %Reset angle calibration
            obj.StandingOffsetAngle = [];
            obj.FullFlexionAngle = [];
            notify( obj, "DevicesConnectedChanged" )

        end % disconnectDevice

        function devicesConnected = bothIMUDevicesConnected( obj )
            devicesConnected = (obj.IMUDevices(1).IsConnected && obj.IMUDevices(2).IsConnected);
        end

        function devicesConfigured = bothIMUDevicesConfigured( obj )
            devicesConfigured = (obj.IMUDevices(1).IsConfigured && obj.IMUDevices(2).IsConfigured);
        end

        function devicesStreaming = bothIMUDevicesStreaming( obj )
            devicesStreaming = (obj.IMUDevices(1).IsStreaming && obj.IMUDevices(2).IsStreaming);
        end

        function anglesCalibrated = calibrationCompleted( obj )
            anglesCalibrated = ~isempty(obj.StandingOffsetAngle) && ~isempty(obj.FullFlexionAngle); 
        end

        function batteryInfo = getBatteryInfo( obj, deviceIndex )
            % GETBATTERYINFO Get battery information of the IMU

            if ( obj.OperationInProgress )
                return
            end
            operationStarted( obj );

            batteryInfo = obj.IMUDevices(deviceIndex).BatteryInfo;

            operationCompleted( obj );
        end

        function configured = configure( obj, deviceIndex, samplingRate )
            %CONFIGURE Configure the IMU with the specified sampling rate

            configured = false;
            if ( obj.OperationInProgress )
                return
            end
            operationStarted( obj );

            device = obj.IMUDevices(deviceIndex);
            configured = device.configure(samplingRate);

            operationCompleted( obj );

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

        function calibrated = calibrateAngle( obj, angleType )
            % CALIBRATEANGLE Calibrate the standing or full flexion angle.
            % "f" for Full Flexion, "s" for standing offset

            arguments
                obj
                angleType string
            end

            calibrated = false;
            if (obj.OperationInProgress || isInvalidAngleType( obj, angleType ) || (isempty(obj.StandingOffsetAngle) && strcmp(angleType, "f")))
                return
            end
            operationStarted( obj );

            startStreamingBoth( obj );
            calibrated = true;
            try
                if (strcmp(angleType, "s"))
                    angle = 0 - obj.LatestAngle;
                else
                    angle = obj.LatestCalibratedAngle;
                end
            catch
                calibrated = false;
                warning("Failed to retrieve angle. Could not calibrate.");
            end

            if (calibrated)
                if (strcmp(angleType, "s"))
                    obj.StandingOffsetAngle = angle;
                    obj.FullFlexionAngle = [];
                    notify( obj, "StandingOffsetAngleCalibrated" )
                else
                    obj.FullFlexionAngle = angle;
                    notify( obj, "FullFlexionAngleCalibrated" )
                end
            end

            operationCompleted( obj );
            notify( obj, "OperationCompleted" )
        end

        function isInvalid = isInvalidAngleType( ~, angleType )
            isInvalid = ~strcmp(angleType, "s") && ~strcmp(angleType, "f");
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

            notify( obj, "OperationStarted" )
        end

        function operationCompleted( obj )
            obj.OperationInProgress = false;

            notify( obj, "OperationCompleted" )
        end

        function angle = calculateAngle( ~, quat3dDifference)
            %CALCULATEANGLE Find the angle between the IMUs in terms of the
            %horizontal plane

            eulerZYX = quat2eul(quat3dDifference);

            angle = rad2deg(eulerZYX(3));
        end % calculateAngle

        function quat3dDifference = getQuat3dDifference( obj )
            %GETQUAT3DDIFFERENCE Find the difference between IMU
            %quaternions.

            quaternion1 = obj.IMUDevices(2).LatestQuaternion;
            quaternion2 = obj.IMUDevices(1).LatestQuaternion;

            quat3dDifference = quatmultiply(quatconj(quaternion1), quaternion2);
        end

    end

end % classdef