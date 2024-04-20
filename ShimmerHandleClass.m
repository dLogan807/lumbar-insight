% Code modified from the official Instrumentation Driver.
% Shimmer. (2022). Shimmer Matlab Instrumentation Driver. https://github.com/ShimmerEngineering/Shimmer-MATLAB-ID
% No Shimmer 2/2r support.
% Only supports 9DOF daughter board and assumes latest Shimmer3 firmware.
% Reduced functionality due to time constraints and project goals.

classdef ShimmerHandleClass < handle
    %Class to interface with a Shimmer3 device over bluetooth
    
    properties (Constant = true)
        %See the BtStream for Shimmer Firmware User Manual for more
        commandIdentifiers = struct("INQUIRY_COMMAND",0x01,"SET_SENSORS_COMMAND",0x08, "START_STREAMING_COMMAND", 0x07, "STOP_STREAMING_COMMAND", 0x20);

        % Shimmer3:
        SENSOR_A_ACCEL            = 8;   % 0x000080
        SENSOR_GYRO               = 7;   % 0x000040
        SENSOR_MAG                = 6;   % 0x000020
        SENSOR_EXG1_24BIT         = 5;   % 0x000010
        SENSOR_EXG2_24BIT         = 4;   % 0x000008
        SENSOR_GSR                = 3;   % 0x000004
        SENSOR_EXT_A7             = 2;   % 0x000002
        SENSOR_BRIDGE_AMP         = 16;  % 0x8000   
        SENSOR_EXT_A6             = 1;   % 0x000001
        SENSOR_VBATT              = 14;  % 0x002000
        SENSOR_WR_ACCEL           = 13;  % 0x001000
        SENSOR_EXT_A15            = 12;  % 0x000800
        SENSOR_INT_A1             = 11;  % 0x000400
        SENSOR_INT_A12            = 10;  % 0x000200
        SENSOR_INT_A13            = 9;   % 0x000100
        SENSOR_INT_A14            = 24;  % 0x800000
        SENSOR_MPU9150_ACCEL      = 23;  % 0x400000
        SENSOR_MPU9150_MAG        = 22;  % 0x200000
        SENSOR_EXG1_16BIT         = 21;  % 0x100000
        SENSOR_EXG2_16BIT         = 20;  % 0x080000
        SENSOR_BMP180_PRESSURE    = 19;  % 0x040000
        SENSOR_BMP180_TEMPERATURE = 18;  % 0x020000

        InternalBoard = "9DOF";
    end

    properties
        name (1,:) {string};
        bluetoothConn bluetooth;
        isConnected {logical} = false;
        isStreaming {logical} = false;
    end
    
    methods
        %Constructor
        function thisShimmer = ShimmerHandleClass(name)
            arguments 
                name;
            end

            thisShimmer.name = name;
        end

        %Connect to the Shimmer
        function isConnected = connect(thisShimmer)
            thisShimmer.isConnected = false;
            
            try
                thisShimmer.bluetoothConn = bluetooth(thisShimmer.name);
                thisShimmer.isConnected = true;
            catch
            end

            isConnected = thisShimmer.isConnected;
        end

        %Check if the command was acknowledged by the device
        function received = commandReceived(thisShimmer)
            data = read(thisShimmer.bluetoothConn, 1);

            received = (data == 255);
        end

        %Start streaming
        function startedStreaming = startStreaming(thisShimmer)
            startedStreaming = false;

            if (thisShimmer.isConnected && ~thisShimmer.isStreaming)
                flush(thisShimmer.bluetoothConn);
                write(thisShimmer.bluetoothConn, thisShimmer.commandIdentifiers.START_STREAMING_COMMAND);
                
                startedStreaming = commandReceived(thisShimmer);
                thisShimmer.isStreaming = startedStreaming;
            end
        end

        %Stop streaming
        function stoppedStreaming = stopStreaming(thisShimmer)
            stoppedStreaming = false;

            if (thisShimmer.isConnected && thisShimmer.isStreaming)
                flush(thisShimmer.bluetoothConn);
                write(thisShimmer.bluetoothConn, thisShimmer.commandIdentifiers.STOP_STREAMING_COMMAND);
   
                thisShimmer.isStreaming = false;
                stoppedStreaming = true;
            end
        end

        %Disable all sensors
        function sensorsDisabled = disableAllSensors(thisShimmer)
            enabledSensors = 0;

            sensorsDisabled = writeEnabledSensors(thisShimmer, uint32(enabledSensors));
        end

        %Set specifc enabled sensors
        %Example: Enable the gyroscope, magnetometer and accelerometer.
        %shimmer.setenabledsensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,SensorMacros.ACCEL,1);   
        function sensorsSet = setEnabledSensors(thisShimmer, varargin)
            enabledSensors = determineEnabledSensorsBytes(thisShimmer, varargin);

            sensorsSet = writeEnabledSensors(thisShimmer, uint32(enabledSensors));  
        end

        %Write the enabled sensors to the shimmer
        function areEnabled = writeEnabledSensors(thisShimmer, enabledSensors)
            areEnabled = false;

            stopStreaming(thisShimmer);

            if (thisShimmer.isConnected)
                flush(thisShimmer.bluetoothConn);

                enabledSensorsLowByte = bitand(enabledSensors,255);                     % Extract the lower byte
                enabledSensorsHighByte = bitand(bitshift(enabledSensors,-8),255);       % Extract the higher byte
                enabledSensorsHigherByte = bitand(bitshift(enabledSensors,-16),255);    % Extract the higher byte
               
                write(thisShimmer.bluetoothConn, thisShimmer.commandIdentifiers.SET_SENSORS_COMMAND);
                write(thisShimmer.bluetoothConn, char(enabledSensorsLowByte));           % Write the enabled sensors lower byte value to the Shimmer
                write(thisShimmer.bluetoothConn, char(enabledSensorsHighByte));          % Write the enabled sensors higher byte value to the Shimmer
                write(thisShimmer.bluetoothConn, char(enabledSensorsHigherByte));        % Write the enabled sensors higher byte value to the Shimmer

                areEnabled = commandReceived(thisShimmer);
            end
        end

        % Determines which sensors should be enabled/disabled based on
        % the input settingsCellArray.
        function enabledSensors = determineEnabledSensorsBytes(thisShimmer, settingsCellArray)
            enabledSensors = uint32(0); 
            
            iSensor = 1;
            while iSensor < (length(settingsCellArray))
                
                sensorName = char(settingsCellArray(iSensor));
                enableBit = cell2mat(settingsCellArray(iSensor+1));
                
                switch sensorName
                    case('Accel')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_A_ACCEL, enableBit);        % set the accel enabled setting to the value in enable bit
                        
                    case('LowNoiseAccel')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_A_ACCEL, enableBit);        % set the accel enabled setting to the value in enable bit
                        
                    case('WideRangeAccel')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_WR_ACCEL, enableBit);       % set the accel enabled setting to the value in enable bit
                        
                    case('AlternativeAccel')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_MPU9150_ACCEL, enableBit);       % set the accel enabled setting to the value in enable bit
                        if (enableBit)
                            disp('Warning: determineenabledsensorsbytes - Note that calibration of the Alternative Accelerometer is not supported for the moment, please use wide range accel or low noise accel.');
                        end
                         
                    case('Gyro')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_GYRO, enableBit);        % set the Gyro enabled setting to the value in enable bit
                        
                    case('Mag')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_MAG, enableBit);         % set the Gyro enabled setting to the value in enable bit
                        
                    case('AlternativeMag')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_MPU9150_MAG, enableBit); % set the accel enabled setting to the value in enable bit
                        if(enableBit)
                            disp('Warning: determineenabledsensorsbytes - Note that calibration of the Alternative Magnetometer is not supported for the moment, please use Mag');
                        end
        
                    case('BattVolt')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_VBATT, enableBit);      % set the BattVolt enabled setting to the value in enable bit
                        
                    case('INT A1')
                        if (~strcmp(thisShimmer.InternalBoard,'EXG')...
                                && ~strcmp(thisShimmer.InternalBoard,'ECG') && ~strcmp(thisShimmer.InternalBoard,'EMG')...
                                && ~strcmp(thisShimmer.InternalBoard,'GSR'))
                            enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A1, enableBit);              % enable internal ADC A1, only if SENSOR_GSR and ExG sensors are disabled
                        else
                            if(enableBit)
                                fprintf('Warning: determineenabledsensorsbytes - INT A1 option only supported on Shimmer3,\n');
                                fprintf('when ExG and GSR sensors are disabled.');
                            end
                        end
                        
                    case('INT A12')
                        if (~strcmp(thisShimmer.InternalBoard,'EXG')...
                                && ~strcmp(thisShimmer.InternalBoard,'ECG') && ~strcmp(thisShimmer.InternalBoard,'EMG')...
                                && ~strcmp(thisShimmer.InternalBoard,'Bridge Amplifier'))
                            enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A12, enableBit);              % enable internal ADC A12, only if SENSOR_BRIDGE_AMP and ExG sensors are disabled
                        else
                            if(enableBit)
                                fprintf('Warning: determineenabledsensorsbytes - INT A12 option only supported on Shimmer3,\n');
                                fprintf('when ExG and Bridge Amplifier sensors are disabled.');
                            end
                        end
                        
                    case('INT A13')
                        if (~strcmp(thisShimmer.InternalBoard,'EXG')...
                                && ~strcmp(thisShimmer.InternalBoard,'ECG') && ~strcmp(thisShimmer.InternalBoard,'EMG')...
                                && ~strcmp(thisShimmer.InternalBoard,'Bridge Amplifier'))
                            enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A13, enableBit);              % enable internal ADC A13, only if SENSOR_BRIDGE_AMP and ExG sensors are disabled
                        else
                            if(enableBit)
                                fprintf('Warning: determineenabledsensorsbytes - INT A13 option only supported on Shimmer3,\n');
                                fprintf('when ExG and Bridge Amplifier sensors are disabled.');
                            end
                        end
                        
                    case('INT A14')
                        if (~strcmp(thisShimmer.InternalBoard,'EXG')...
                                && ~strcmp(thisShimmer.InternalBoard,'ECG') && ~strcmp(thisShimmer.InternalBoard,'EMG')...
                                && ~strcmp(thisShimmer.InternalBoard,'Bridge Amplifier') && ~strcmp(thisShimmer.InternalBoard,'GSR'))
                            enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A14, enableBit);              % enable internal ADC A14, only if SENSOR_BRIDGE_AMP, SENSOR_GSR and ExG sensors are disabled
                        else
                            if(enableBit)
                                fprintf('Warning: determineenabledsensorsbytes - INT A14 option only supported on Shimmer3,\n');
                                fprintf('when ExG, GSR and Bridge Amplifier sensors are disabled.');
                            end
                        end
                        
                    case('Pressure')
                        enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_BMP180_PRESSURE, enableBit);
                    otherwise
                        if(enableBit)
                            fprintf(strcat('Warning: determineenabledsensorsbytes - Attempt to enable unrecognised sensor on Shimmer COM', thisShimmer.name, '.\n'));
                        end
                end
                
                iSensor = iSensor + 2;
            end
                    
            enabledSensors = disableunavailablesensors(thisShimmer, enabledSensors);    % Update enabledSensors value to disable unavailable sensors based on daughter board settings
            
        end   
    

        function enabledSensors = disableunavailablesensors(thisShimmer, enabledSensors)
            % Disables conflicting sensors based on input enabledSensors.
            internalBoard = char(thisShimmer.InternalBoard);
                        
            switch internalBoard
                case ('None')
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG1_24BIT, 0);      % disable SENSOR_EXG1_24BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG2_24BIT, 0);      % disable SENSOR_EXG2_24BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG1_16BIT, 0);      % disable SENSOR_EXG1_16BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG2_16BIT, 0);      % disable SENSOR_EXG2_16BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_BRIDGE_AMP, 0);      % disable SENSOR_BRIDGE_AMP
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_GSR, 0);             % disable SENSOR_GSR
                   
                case ('ECG')
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A1, 0);          % disable SENSOR_INT_A1
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A12, 0);         % disable SENSOR_INT_A12
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A13, 0);         % disable SENSOR_INT_A13
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A14, 0);         % disable SENSOR_INT_A14
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_BRIDGE_AMP, 0);      % disable SENSOR_BRIDGE_AMP
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_GSR, 0);             % disable SENSOR_GSR
                                        
                case ('EMG')
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A1, 0);          % disable SENSOR_INT_A1
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A12, 0);         % disable SENSOR_INT_A12
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A13, 0);         % disable SENSOR_INT_A13
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A14, 0);         % disable SENSOR_INT_A14
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG2_24BIT, 0);      % disable SENSOR_EXG2_24BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG2_16BIT, 0);      % disable SENSOR_EXG2_16BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_BRIDGE_AMP, 0);      % disable SENSOR_BRIDGE_AMP
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_GSR, 0);             % disable SENSOR_GSR
                    
                case ('EXG')
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A1, 0);          % disable SENSOR_INT_A1
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A12, 0);         % disable SENSOR_INT_A12
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A13, 0);         % disable SENSOR_INT_A13
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A14, 0);         % disable SENSOR_INT_A14
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_BRIDGE_AMP, 0);      % disable SENSOR_BRIDGE_AMP
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_GSR, 0);             % disable SENSOR_GSR
                    
                case ('GSR')
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG1_24BIT, 0);      % disable SENSOR_EXG1_24BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG2_24BIT, 0);      % disable SENSOR_EXG2_24BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG1_16BIT, 0);      % disable SENSOR_EXG1_16BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG2_16BIT, 0);      % disable SENSOR_EXG2_16BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A1, 0);          % disable SENSOR_INT_A1
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A14, 0);         % disable SENSOR_INT_A14
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_BRIDGE_AMP, 0);      % disable SENSOR_BRIDGE_AMP
                    
                case ('Bridge Amplifier')
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A12, 0);         % disable SENSOR_INT_A12
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A13, 0);         % disable SENSOR_INT_A13
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_INT_A14, 0);         % disable SENSOR_INT_A14
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG1_24BIT, 0);      % disable SENSOR_EXG1_24BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG2_24BIT, 0);      % disable SENSOR_EXG2_24BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG1_16BIT, 0);      % disable SENSOR_EXG1_16BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_EXG2_16BIT, 0);      % disable SENSOR_EXG2_16BIT
                    enabledSensors = bitset(uint32(enabledSensors), thisShimmer.SENSOR_GSR, 0);             % disable SENSOR_GSR
            end                   
        end
    end
end