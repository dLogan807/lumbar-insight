classdef ShimmerIMU < IMUInterface
    %SHIMMERIMU Class implmenting IMU Interface, utilising the Shimmer
    %driver
    
    properties (GetAccess = private, SetAccess = immutable)
        Driver ShimmerDriver
        LowBatteryVoltageLevel int8 = 3700
    end

    properties (SetAccess = protected)
        Name
        IsConnected = false
        IsStreaming = false
        IsConfigured = false
        LatestQuaternion
        BatteryInfo
        SamplingRates = [60 120]
        SamplingRate = -1
    end
    
    methods
        function obj = ShimmerIMU( deviceName )
            %SHIMMERIMU Constructor

            obj.Name = deviceName;

            obj.Driver = ShimmerDriver( deviceName );
        end

        function isConnected = get.IsConnected( obj )
            %GET.ISCONNECTED Return the imu's streaming state 

            isConnected = false;

            state = obj.Driver.State;

            if (~strcmp(state, 'Disconnected'))
                isConnected = true;
            end
        end

        function isStreaming = get.IsStreaming( obj )
            %GET.ISSTREAMING Return the imu's streaming logical

            isStreaming = false;

            state = obj.Driver.State;

            if (strcmp(state, 'Streaming'))
                isStreaming = true;
            end
        end

        function batteryInfo = get.BatteryInfo( obj )
            %GET.BATTERYINFO Return a string describing the IMU's battery state

            state = obj.Driver.State;

            wasStreaming = strcmp(state, 'Streaming');

            if (wasStreaming)
                obj.stopStreaming;
            end

            if (strcmp(state, "Connected"))
                batteryVoltage = obj.Driver.getbatteryvoltage;

                if (strcmp(state, "Connected") && batteryVoltage <= obj.LowBatteryVoltageLevel)
                    batteryInfo = obj.Name + " battery low! (" + batteryVoltage + "mV)";
                else
                    batteryInfo = obj.Name + " (" + batteryVoltage + "mV)";
                end
            else
                batteryInfo = "Not connected. No battery information.";
            end

            if (wasStreaming)
                obj.startStreaming;
            end
        end

        function latestQuaternion = get.LatestQuaternion(obj)
            %LATESTQUATERNION Retrieve the most recent quaternion from the
            %IMU

            wasStreaming = obj.IsStreaming;
            ME = [];

            if (~wasStreaming)
                obj.startStreaming;
            end

            try
                [shimmerData,shimmerSignalNameArray,~,~] = obj.Driver.getdata('c');

                if (~isempty(shimmerData))
                    shimmerQuaternionChannels(1) = find(ismember(shimmerSignalNameArray, 'Quaternion 0'));                  % Find Quaternion signal indices.
                    shimmerQuaternionChannels(2) = find(ismember(shimmerSignalNameArray, 'Quaternion 1'));
                    shimmerQuaternionChannels(3) = find(ismember(shimmerSignalNameArray, 'Quaternion 2'));
                    shimmerQuaternionChannels(4) = find(ismember(shimmerSignalNameArray, 'Quaternion 3'));
    
                    latestQuaternion = shimmerData(end, shimmerQuaternionChannels);
                else
                    ME = MException("LatestQuaternion:noData", "Data could not be retrieved from %s" + obj.Name);
                end
            catch exception
                ME = exception;
            end

            if (~wasStreaming)
                obj.stopStreaming;
            end

            %Rethrow if exception occured
            if (~isempty(ME))
                rethrow(ME);
            end

        end

        function connected = connect(obj)
            %CONNECT Connect to the Shimmer over Bluetooth

            obj.IsConnected = false;
            obj.IsStreaming = false;
            obj.IsConfigured = false;

            connected = obj.Driver.connect;
        end

        function disconnected = disconnect(obj)
            %DISCONNECT Disconnect from the Shimmer

            obj.IsConfigured = false;
            obj.SamplingRate = -1;
            disconnected = obj.Driver.disconnect;
        end

        function configured = configure( obj, samplingRate )
            %CONFIGURE Configures the Shimmer

            SensorMacros = ShimmerEnabledSensorsMacrosClass;                          % assign user friendly macros for setenabledsensors

            if (setSamplingRate(obj, samplingRate))
    	        obj.Driver.setinternalboard('9DOF');                                      % Set the shimmer internal daughter board to '9DOF'
                obj.Driver.disableallsensors;                                             % disable all sensors
                obj.Driver.setenabledsensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,...   % Enable the gyroscope, magnetometer and accelerometer.
                SensorMacros.ACCEL,1);                                                  
                obj.Driver.setaccelrange(0);                                              % Set the accelerometer range to 0 (+/- 1.5g for Shimmer2/2r, +/- 2.0g for Shimmer3)
                obj.Driver.setorientation3D(1);                                           % Enable orientation3D
                obj.Driver.setgyroinusecalibration(1);                                    % Enable gyro in-use calibration

                obj.IsConfigured = true;
                configured = true;
            else
                obj.IsConfigured = false;
                configured = false;
            end
        end

        function rateSet = setSamplingRate( obj, samplingRate )
            %SETSAMPLINGRATE Sets the sampling rate and then sets sensors 
            %as closely as possible to it

            if (ismember(samplingRate, obj.SamplingRates))
                isNumber = ~strcmp(obj.Driver.setsamplingrate( samplingRate ), 'Nan');
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
            %STARTSTREAMING Start streaming data
            if (obj.IsStreaming)
                started = true;
            else
                started = obj.Driver.start;
            end
        end

        function stopped = stopStreaming(obj)
            %STOPSTREAMING Stop streaming data
            if (obj.IsStreaming)
                stopped = obj.Driver.stop;
            else
                stopped = true;
            end
        end
    end
end
