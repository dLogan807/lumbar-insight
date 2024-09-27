classdef Model < handle
    %Application data model.

    properties
        %Application data.

        IMUDevices (1, 2) IMUInterface = [ShimmerIMU("placeholder1"), ShimmerIMU("placeholder2")]

        Cameras (:, 2) Camera

        PollingRateOverride double = 20
        PollingOverrideEnabled logical = false

        BeepEnabled logical = true
        BeepRate double = 1
    end

    properties (SetAccess = private, GetAccess = public)
        FileExportManager FileWriter
        StreamingInProgress logical = false
        RecordingInProgress logical = false
        OperationInProgress logical = false

        LatestAngle double
        LatestCalibratedAngle double
        FullFlexionAngle double = []
        StandingOffsetAngle double = []

        DecimalThresholdPercentage double {mustBePositive}
        ThresholdAngle double = []
        
        SmallestStreamedAngle double = [];
        LargestStreamedAngle double = [];
        TimeAboveThreshold double = 0

        SmallestRecordedAngle double = [];
        LargestRecordedAngle double = [];
        RecordedTimeAboveThreshold double = 0
        TimeRecording double = 0
    end

    properties (Access = private)
        BeepSoundData
        BeepSoundSampleRate
    end

    events (NotifyAccess = private)
        %Events broadcast when the model is altered.
        OperationStarted
        OperationCompleted

        DevicesConnectedChanged
        DevicesConfiguredChanged

        StandingOffsetAngleCalibrated
        FullFlexionAngleCalibrated

    end % events ( NotifyAccess = private )

    methods

        function obj = Model()
            %Constructor. Initialises beep warning sound and data exporting
            [obj.BeepSoundData, obj.BeepSoundSampleRate] = audioread('warningbeep.mp3');
            obj.FileExportManager = FileWriter("data");
        end

        function latestAngle = get.LatestAngle(obj)
            %Update and store the latest angle between the
            %IMUs

            quat3dDifference = getQuat3dDifference(obj);
            latestAngle = calculateAngle(obj, quat3dDifference);
        end

        function latestCalibratedAngle = get.LatestCalibratedAngle(obj)
            %Get the latest angle zeroed to the
            %subject's standing position.

            if (isempty(obj.StandingOffsetAngle))
                ME = MException("LatestCalibratedAngle: Standing offset angle not calibrated!");
                throw(ME)
            end

            latestCalibratedAngle = obj.LatestAngle + obj.StandingOffsetAngle;
        end

        function updateCeilingAngles(obj, angle)
            %Update the smallest and largest angles stored

            arguments
                obj 
                angle double {mustBeNonempty} 
            end

            if (obj.StreamingInProgress)
                [obj.SmallestStreamedAngle, obj.LargestStreamedAngle] = findExtremities(obj, obj.SmallestStreamedAngle, obj.LargestStreamedAngle, angle);

                if (obj.RecordingInProgress)
                    [obj.SmallestRecordedAngle, obj.LargestRecordedAngle] = findExtremities(obj, obj.SmallestRecordedAngle, obj.LargestRecordedAngle, angle);
                end
            end
        end

        function addTimeAboveThreshold(obj, seconds)
            %Add time to when subject is above threshold angle

            arguments
                obj 
                seconds double {mustBeNonempty}
            end

            if (obj.StreamingInProgress)
                obj.TimeAboveThreshold = obj.TimeAboveThreshold + seconds;

                if (obj.RecordingInProgress)
                    obj.RecordedTimeAboveThreshold = obj.RecordedTimeAboveThreshold + seconds;
                end
            end
        end

        function setThresholdValues(obj, thresholdPercentage)
            %Store percentage value threshold and calculate threshold angle

            arguments
                obj
                thresholdPercentage double {mustBePositive}
            end

            obj.DecimalThresholdPercentage = thresholdPercentage * 0.01;

            if (obj.calibrationCompleted)
                obj.ThresholdAngle = obj.FullFlexionAngle * obj.DecimalThresholdPercentage;
            end
        end

        function connected = connectDevice(obj, deviceName, deviceType, deviceIndex)
            %Attempt device connection, notify controller,
            % and configure device

            arguments
                obj
                deviceName string
                deviceType DeviceTypes
                deviceIndex int8 {mustBeInRange(deviceIndex, 1, 2)}
            end

            connected = false;

            if (obj.OperationInProgress || isempty(deviceName))
                notify(obj, "DevicesConnectedChanged")
                return
            end

            operationStarted(obj);

            if (deviceType == DeviceTypes.Shimmer)
                obj.IMUDevices(deviceIndex) = ShimmerIMU(deviceName);
                connected = obj.IMUDevices(deviceIndex).connect;
            else
                disp("Device of type " + string(deviceType) + " is not implemented.");
            end

            operationCompleted(obj);

            %Reset angle calibration
            obj.FullFlexionAngle = [];
            obj.StandingOffsetAngle = [];
            obj.ThresholdAngle = [];
            notify(obj, "DevicesConnectedChanged")

        end % connectDevice

        function disconnected = disconnectDevice(obj, deviceIndex)
            %Disconnect a device

            disconnected = false;

            if (obj.OperationInProgress)
                return
            end

            operationStarted(obj);

            disconnected = obj.IMUDevices(deviceIndex).disconnect;

            obj.IMUDevices(deviceIndex) = ShimmerIMU("placeholder" + deviceIndex);

            operationCompleted(obj);

            %Reset angle calibration
            obj.StandingOffsetAngle = [];
            obj.FullFlexionAngle = [];
            obj.ThresholdAngle = [];
            notify(obj, "DevicesConnectedChanged")

        end % disconnectDevice

        function devicesConnected = bothIMUDevicesConnected(obj)
            devicesConnected = (obj.IMUDevices(1).IsConnected && obj.IMUDevices(2).IsConnected);
        end

        function devicesConfigured = bothIMUDevicesConfigured(obj)
            devicesConfigured = (obj.IMUDevices(1).IsConfigured && obj.IMUDevices(2).IsConfigured);
        end

        function devicesStreaming = bothIMUDevicesStreaming(obj)
            devicesStreaming = (obj.IMUDevices(1).IsStreaming && obj.IMUDevices(2).IsStreaming);
        end

        function anglesCalibrated = calibrationCompleted(obj)
            anglesCalibrated = ~isempty(obj.StandingOffsetAngle) && ~isempty(obj.FullFlexionAngle);
        end

        function batteryInfo = getBatteryInfo(obj, deviceIndex)
            %Get battery information of the IMU

            arguments
                obj
                deviceIndex int8 {mustBeInRange(deviceIndex, 1, 2)}
            end

            if (obj.OperationInProgress)
                batteryInfo = "An operation was ongoing. Failed to retrieve.";
                return
            elseif (obj.StreamingInProgress)
                batteryInfo = "Battery info cannot be retrieved whilst streaming.";
                return
            end

            operationStarted(obj);

            batteryInfo = obj.IMUDevices(deviceIndex).BatteryInfo;

            operationCompleted(obj);
        end

        function configured = configure(obj, deviceIndex, samplingRate)
            %Configure the IMU with the specified sampling rate

            arguments
                obj
                deviceIndex int8 {mustBeInRange(deviceIndex, 1, 2)}
                samplingRate double {mustBePositive}
            end

            configured = false;

            if (obj.OperationInProgress)
                return
            end

            operationStarted(obj);

            device = obj.IMUDevices(deviceIndex);
            configured = device.configure(samplingRate);

            operationCompleted(obj);

            notify(obj, "DevicesConfiguredChanged")
        end

        function pollingRate = getPollingRate(obj)
            %Polling rate is lowest sampling rate or defined override

            pollingRate = -1;

            if (obj.PollingOverrideEnabled)
                pollingRate = obj.PollingRateOverride;
                return
            end

            if (obj.IMUDevices(1).IsConfigured)
                pollingRate = obj.IMUDevices(1).SamplingRate;
            end

            device2Rate = obj.IMUDevices(2).SamplingRate;

            if (obj.IMUDevices(2).IsConfigured && (device2Rate < pollingRate))
                pollingRate = device2Rate;
            end

        end

        function calibrated = calibrateAngle(obj, angleType)
            %Calibrate the standing or full flexion angle.
            % "f" for Full Flexion, "s" for standing offset

            arguments
                obj
                angleType string {mustBeTextScalar}
            end

            calibrated = false;

            if (obj.OperationInProgress || isInvalidAngleType(obj, angleType) || ...
                    (isempty(obj.StandingOffsetAngle) && strcmp(angleType, "f")))
                return
            end

            operationStarted(obj);

            startStreamingBoth(obj);
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
                    notify(obj, "StandingOffsetAngleCalibrated")
                else
                    obj.FullFlexionAngle = angle;
                    notify(obj, "FullFlexionAngleCalibrated")
                end

            end

            operationCompleted(obj);
            notify(obj, "OperationCompleted")
        end

        function startedBoth = startStreamingBoth(obj)
            %Start streaming on both devices, if
            %possible

            device1 = obj.IMUDevices(1);
            device2 = obj.IMUDevices(2);

            if (device1.IsConnected && ~device1.IsStreaming)
                device1.startStreaming;
            end

            if (device2.IsConnected && ~device2.IsStreaming)
                device2.startStreaming;
            end

            if (device1.IsStreaming && device2.IsStreaming)
                startedBoth = true;
                pause(2); %Wait for data
            else
                startedBoth = false;
            end

        end

        function stopStreamingBoth(obj)
            %Stop streaming on both devices

            device1 = obj.IMUDevices(1);
            device2 = obj.IMUDevices(2);

            if (device1.IsConnected && device1.IsStreaming)
                device1.stopStreaming;
            end

            if (device2.IsConnected && device2.IsStreaming)
                device2.stopStreaming;
            end

        end

        function started = startSessionStreaming(obj)

            started = startStreamingBoth(obj);

            if (started)
                obj.SmallestStreamedAngle = [];
                obj.LargestStreamedAngle = [];
                obj.TimeAboveThreshold = 0;

                obj.StreamingInProgress = true;
            end

        end

        function stopSessionStreaming(obj)

            obj.StreamingInProgress = false;

            stopStreamingBoth(obj);
            stopRecording(obj);

        end

        function startRecording(obj)
            %Create a file to write to and start recording data

            if (obj.StreamingInProgress)
                obj.TimeRecording = 0;
                obj.SmallestRecordedAngle = [];
                obj.LargestRecordedAngle = [];
                obj.RecordedTimeAboveThreshold = 0;

                obj.FileExportManager.initialiseNewFile();
                obj.RecordingInProgress = true;
            end

        end

        function stopRecording(obj)
            %Stop recording, close the file with session stats, and reset
            %recording data

            if (obj.RecordingInProgress)
                obj.RecordingInProgress = false;

                csvData = [obj.SmallestRecordedAngle, obj.LargestRecordedAngle, obj.RecordedTimeAboveThreshold, obj.TimeRecording];

                obj.FileExportManager.closeFile(csvData);
            end
        end

        function playWarningBeep(obj)
            sound(obj.BeepSoundData, obj.BeepSoundSampleRate);
        end

    end % methods

    methods (Access = private)

        function operationStarted(obj)
            obj.OperationInProgress = true;

            notify(obj, "OperationStarted")
        end

        function operationCompleted(obj)
            obj.OperationInProgress = false;

            notify(obj, "OperationCompleted")
        end

        function [smallestAngle, largestAngle] = findExtremities(~, smallestAngle, largestAngle, angle)
            %Check if the angle is smaller or larger than specified values.

            arguments
                ~ 
                smallestAngle double
                largestAngle double
                angle double {mustBeNonempty}
            end

            if (isempty(smallestAngle) || angle < smallestAngle)
                smallestAngle = angle;
            end

            if (isempty(largestAngle) || angle > largestAngle)
                largestAngle = angle;
            end
        end

        function isInvalid = isInvalidAngleType(~, angleType)

            arguments
                ~
                angleType string {mustBeTextScalar}
            end

            isInvalid = ~strcmp(angleType, "s") && ~strcmp(angleType, "f");
        end

        function quat3dDifference = getQuat3dDifference(obj)
            %Find the difference between IMU quaternions.

            quaternion1 = obj.IMUDevices(2).LatestQuaternion;
            quaternion2 = obj.IMUDevices(1).LatestQuaternion;

            quat3dDifference = quatmultiply(quatconj(quaternion1), quaternion2);
        end

        function angle = calculateAngle(~, quat3dDifference)
            %Find the angle between the IMUs in terms of the
            %X axis.

            eulerZYX = quat2eul(quat3dDifference);

            angle = rad2deg(eulerZYX(3));
        end

    end

end % classdef
