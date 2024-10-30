classdef ShimmerIMU < IMUInterface
    %Class implementing IMU Interface, utilising the Shimmer
    %driver.

    properties (GetAccess = private, SetAccess = immutable)
        Driver ShimmerDriver
        LowBatteryVoltageLevel int8 = 3700
    end

    properties (SetAccess = protected)
        Name
        IsConfigured = false
        BatteryInfo
        SamplingRates = [60 120]
        SamplingRate = -1
    end

    properties (SetAccess = protected, Dependent)
        IsConnected
        IsStreaming
        LatestQuaternion
    end

    methods

        function obj = ShimmerIMU(deviceName)
            %Constructor

            arguments
                deviceName string {mustBeTextScalar}
            end

            obj.Name = deviceName;

            obj.Driver = ShimmerDriver(deviceName);
        end

        function isConnected = get.IsConnected(obj)
            %Return the imu's streaming state

            isConnected = false;

            state = obj.Driver.getstate();

            if (~strcmp(state, 'Disconnected'))
                isConnected = true;
            end

        end

        function isStreaming = get.IsStreaming(obj)
            %Return the imu's streaming logical

            isStreaming = false;

            state = obj.Driver.getstate();

            if (strcmp(state, 'Streaming'))
                isStreaming = true;
            end

        end

        function batteryInfo = get.BatteryInfo(obj)
            %Return a string describing the IMU's battery state

            obj.stopStreaming;

            state = obj.Driver.getstate();

            if (strcmp(state, "Connected"))
                batteryVoltage = obj.Driver.getbatteryvoltage;

                if (strcmp(batteryVoltage, 'Nan'))
                    batteryInfo = "Unable to retrieve " + obj.Name + " battery voltage.";
                elseif (strcmp(state, "Connected") && batteryVoltage <= obj.LowBatteryVoltageLevel)
                    batteryInfo = obj.Name + " battery low! Voltage: " + batteryVoltage + "mV";
                else
                    batteryInfo = obj.Name + " battery voltage: " + batteryVoltage + "mV";
                end

            elseif (strcmp(state, "Streaming"))
                batteryInfo = "Failed to stop streaming. No battery information.";
            else
                batteryInfo = "Not connected. No battery information.";
            end

        end

        function latestQuaternion = get.LatestQuaternion(obj)
            %Retrieve the most recent quaternion from the
            %Shimmer Bluetooth data buffer

            if (~obj.IsConnected)
                error("LatestQuaternion:DeviceNotConnected", (obj.Name + " is not connected."));
            end

            errorMessage = [];

            startStreaming(obj);

            try
                [shimmerData, shimmerSignalNameArray, ~, ~] = obj.Driver.getdata('c');

                if (~isempty(shimmerData))
                    shimmerQuaternionChannels(1) = find(ismember(shimmerSignalNameArray, 'Quaternion 0')); % Find Quaternion signal indices.
                    shimmerQuaternionChannels(2) = find(ismember(shimmerSignalNameArray, 'Quaternion 1'));
                    shimmerQuaternionChannels(3) = find(ismember(shimmerSignalNameArray, 'Quaternion 2'));
                    shimmerQuaternionChannels(4) = find(ismember(shimmerSignalNameArray, 'Quaternion 3'));

                    latestQuaternion = shimmerData(end, shimmerQuaternionChannels);
                else
                    errorMessage = "Data could not be retrieved from " + obj.Name;
                end

            catch
                errorMessage = "An error occured retrieving data from " + obj.Name;
            end

            %Rethrow if exception occured
            if (~isempty(errorMessage))
                error("LatestQuaternion:DataNotRetrieved", errorMessage);
            end

        end

        function connected = connect(obj)
            %Connect to the Shimmer over Bluetooth

            obj.IsConfigured = false;
            obj.SamplingRate = -1;

            try
                connected = obj.Driver.connect;
            catch
                connected = obj.IsConnected;
            end

        end

        function disconnected = disconnect(obj)
            %Disconnect from the Shimmer

            obj.IsConfigured = false;
            obj.SamplingRate = -1;

            try
                disconnected = obj.Driver.disconnect;
                clear obj.Driver;
            catch
                disconnected = ~obj.IsConnected;
            end

        end

        function configured = configure(obj, samplingRate)
            %Configures the Shimmer

            arguments
                obj
                samplingRate double {mustBePositive}
            end

            if (~obj.IsConnected)
                error("configure:DeviceNotConnected", ("Cannot configure " + obj.Name + " as it is not connected."));
            end

            stopStreaming(obj);

            SensorMacros = ShimmerEnabledSensorsMacrosClass; % assign user friendly macros for setenabledsensors

            try

                if (setSamplingRate(obj, samplingRate))
                    obj.Driver.setinternalboard('9DOF'); % Set the shimmer internal daughter board to '9DOF'
                    obj.Driver.disableallsensors; % disable all sensors
                    obj.Driver.setenabledsensors(SensorMacros.GYRO, 1, SensorMacros.MAG, 1, ... % Enable the gyroscope, magnetometer and accelerometer.
                        SensorMacros.ACCEL, 1);
                    obj.Driver.setaccelrange(0); % Set the accelerometer range to 0 (+/- 1.5g for Shimmer2/2r, +/- 2.0g for Shimmer3)
                    obj.Driver.setorientation3D(1); % Enable orientation3D
                    obj.Driver.setgyroinusecalibration(1); % Enable gyro in-use calibration

                    obj.IsConfigured = true;
                    configured = true;
                else
                    disp("Warning: configure - " + obj.Name + " failed to complete configuration.");
                    obj.IsConfigured = false;
                    configured = false;
                end

            catch
                disp("Warning: configure - " + obj.Name + " failed to complete configuration.");
                obj.IsConfigured = false;
                configured = false;
            end

        end

        function rateSet = setSamplingRate(obj, samplingRate)
            %Sets the sampling rate and then sets sensors
            %as closely as possible to it

            arguments
                obj
                samplingRate double {mustBePositive}
            end

            if (~obj.IsConnected)
                error("setSamplingRate:DeviceNotConnected", ("Cannot set sampling rate of " + obj.Name + " as it is not connected."));
            end

            if (ismember(samplingRate, obj.SamplingRates))
                isNumber = ~strcmp(obj.Driver.setsamplingrate(samplingRate), 'Nan');

                if (isNumber)
                    rateSet = true;
                    obj.SamplingRate = samplingRate;
                else
                    rateSet = false;
                end

            else
                rateSet = false;
                disp("Invalid sampling rate specified for " + obj.Name);
            end

        end

        function started = startStreaming(obj)
            %Start streaming data
            if (obj.IsStreaming)
                started = true;
            else
                try
                    started = obj.Driver.start;
                    pause(2); %Wait for data
                catch exception
                    disp("Error encountered starting streaming of " + obj.Name);
                    disp(exception.message);
                    started = obj.IsStreaming;
                end

            end

        end

        function stopped = stopStreaming(obj)
            %Stop streaming data
            if (obj.IsStreaming)
                try
                    stopped = obj.Driver.stop;
                    pause(2); %Allow time to stop
                catch exception
                    disp("Error encountered stopping streaming of " + obj.Name);
                    disp(exception.message);
                    stopped = ~obj.IsStreaming;
                end

            else
                stopped = true;
            end
        end

    end

end
