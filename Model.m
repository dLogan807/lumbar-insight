classdef Model < handle
    %Application data model.

    properties
        %Application data.

        PollingRateOverride double {mustBeNonempty, mustBePositive} = 20
        PollingOverrideEnabled logical {mustBeNonempty} = false

        BeepEnabled logical = true
        BeepRate double = 1
    end

    properties (SetAccess = private, GetAccess = public)
        IMUDevices (1, 2) IMUInterface = [ShimmerIMU("placeholder1"), ShimmerIMU("placeholder2")]

        Webcam WebCamera
        IPCam IPCamera
        VideoFPS int8 = 10

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
        
        SmallestStreamedAngle double = []
        LargestStreamedAngle double = []
        TimeAboveThreshold double = 0
        TimeStreaming double = 0

        SmallestRecordedAngle double = []
        LargestRecordedAngle double = []
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

        WebcamConnected
        WebcamDisconnected

        IPCamConnected
        IPCamConnectFailed
        IPCamDisconnected

    end % events ( NotifyAccess = private )

    methods

        function obj = Model()
            %Constructor. Initialises beep warning sound and data exporting
            [obj.BeepSoundData, obj.BeepSoundSampleRate] = audioread('warningbeep.mp3');
            obj.FileExportManager = FileWriter("data");
                
            obj.Webcam = WebCamera();
            obj.IPCam = IPCamera();
        end

        function latestAngle = get.LatestAngle(obj)
            %Update and store the latest angle between the
            %IMUs

            if (obj.IMUDevices(1).IsConnected && obj.IMUDevices(2).IsConnected)
                quat3dDifference = getQuat3dDifference(obj);
                latestAngle = calculateAngle(obj, quat3dDifference);
            else
                error("LatestAngle:IMUNotConnected", "At least one IMU is not connected.");
            end
        end

        function latestCalibratedAngle = get.LatestCalibratedAngle(obj)
            %Get the latest angle zeroed to the
            %subject's standing position.

            if (isempty(obj.StandingOffsetAngle))
                error("LatestCalibratedAngle:NotCalibrated", "Standing offset angle not calibrated.");
            end

            latestCalibratedAngle = obj.LatestAngle - obj.StandingOffsetAngle;
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
                seconds double {mustBeNonnegative, mustBeNonempty}
            end

            if (obj.StreamingInProgress)
                obj.TimeAboveThreshold = obj.TimeAboveThreshold + seconds;

                if (obj.RecordingInProgress)
                    obj.RecordedTimeAboveThreshold = obj.RecordedTimeAboveThreshold + seconds;
                end
            end
        end

        function addTimeStreaming(obj, seconds)
            %Add to total time streaming

            arguments
                obj 
                seconds double {mustBeNonnegative, mustBeNonempty}
            end

            if (obj.StreamingInProgress)
                obj.TimeStreaming = obj.TimeStreaming + seconds;

                if (obj.RecordingInProgress)
                    obj.TimeRecording = obj.TimeRecording + seconds;
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

            disconnectDevice(obj, deviceIndex);

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

        function disconnectDevice(obj, deviceIndex)
            %Disconnect a device

            if (obj.OperationInProgress)
                return
            end

            operationStarted(obj);

            obj.IMUDevices(deviceIndex).disconnect();
            clear obj.IMUDevices(deviceIndex)
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

            started = startStreamingBoth(obj);
            if (started)
                try
                    if (strcmp(angleType, "s"))
                        angle = obj.LatestAngle;
                        obj.StandingOffsetAngle = angle;
                        obj.FullFlexionAngle = [];
                        notify(obj, "StandingOffsetAngleCalibrated")
                    else
                        angle = obj.LatestCalibratedAngle;
                        obj.FullFlexionAngle = angle;
                        notify(obj, "FullFlexionAngleCalibrated")
                    end
                    calibrated = true;
                catch exception
                    calibrated = false;
                    disp("Warning: calibrateAngle - Failed to retrieve angle. Could not calibrate.");
                    disp(exception.message)
                end
            else
                calibrated = false;
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
            else
                startedBoth = false;
                disp("Warning: startStreamingBoth - Failed to start streaming.");
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
                obj.TimeStreaming = 0;

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

                obj.FileExportManager.initialiseNewCSV();

                if (obj.Webcam.IsConnected)
                    obj.FileExportManager.initialiseNewVideoFile("Webcam", obj.VideoFPS);
                end

                if (obj.IPCam.IsConnected)
                    obj.FileExportManager.initialiseNewVideoFile("IPCam", obj.VideoFPS);
                end

                obj.RecordingInProgress = true;
            end

        end

        function tryWriteVideo(obj, camera, cameraName)
            %Write to the video file. Abort if an error occurs

            arguments
                obj 
                camera CameraInterface {mustBeNonempty}
                cameraName string {mustBeTextScalar, mustBeNonempty} 
            end

            try
                imageFrame = snapshot(camera.Camera);
                obj.FileExportManager.writeToVideo(cameraName, imageFrame);
            catch
                warning("Could not write to camera. Aborting video recording.")
                camera.disconnect()
            end
        end

        function stopRecording(obj)
            %Stop recording, close the file with session stats, and reset
            %recording data

            if (obj.RecordingInProgress)
                obj.RecordingInProgress = false;

                smallestRecordedAngle = obj.SmallestRecordedAngle;
                if (isempty(obj.SmallestRecordedAngle))
                    smallestRecordedAngle = "?";
                end

                largestRecordedAngle = obj.LargestRecordedAngle;
                if (isempty(obj.LargestRecordedAngle))
                    largestRecordedAngle = "?";
                end

                csvData = [smallestRecordedAngle, largestRecordedAngle, obj.RecordedTimeAboveThreshold, obj.TimeRecording];

                obj.FileExportManager.closeCSVFile(csvData);
                obj.FileExportManager.closeVideoFiles();
            end
        end

        function playWarningBeep(obj)
            sound(obj.BeepSoundData, obj.BeepSoundSampleRate);
        end

        function connectWebcam(obj, cameraName)
            if (obj.Webcam.connect(cameraName))
                notify(obj, "WebcamConnected")
            else
                warning("Could not connect the webcam " + cameraName);
            end
        end

        function disconnectWebcam(obj)
            obj.Webcam.disconnect();

            notify(obj, "WebcamDisconnected")
        end

        function connectIPCam(obj, url, username, password)
            if (obj.IPCam.connect(url, username, password))
                notify(obj, "IPCamConnected")
            else
                notify(obj, "IPCamConnectFailed")
            end
        end

        function disconnectIPCam(obj)
            obj.IPCam.disconnect();

            notify(obj, "IPCamDisconnected")
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

            quaternion1 = obj.IMUDevices(1).LatestQuaternion;
            quaternion2 = obj.IMUDevices(2).LatestQuaternion;

            quat3dDifference = quatmultiply(quatconj(quaternion1), quaternion2);
        end

        function angle = calculateAngle(~, quat3dDifference)
            %Find the angle between the IMUs in terms of the
            %X axis.

            eulerZYX = quat2eul(quat3dDifference);

            angle = 0 - rad2deg(eulerZYX(3));
        end

    end

end % classdef
