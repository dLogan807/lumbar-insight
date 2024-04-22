% Code modified from the official Instrumentation Driver.
% Shimmer. (2022). Shimmer Matlab Instrumentation Driver. https://github.com/ShimmerEngineering/Shimmer-MATLAB-ID
% No Shimmer 2/2r support. Only supports 9DOF daughter board and assumes latest Shimmer3 firmware.
% Reduced functionality due to time constraints and project goals.

classdef ShimmerHandleClass < handle
    %Class to interface with a Shimmer3 device over bluetooth
    
    properties (Constant = true)
        %Commands
        %See the BtStream for Shimmer Firmware User Manual for more

        INQUIRY_COMMAND           = 0x01;
        SET_SENSORS_COMMAND       = 0x08;
        START_STREAMING_COMMAND   = 0x07;
        STOP_STREAMING_COMMAND    = 0x20;

        ACK_RESPONSE              = 255; %Shimmer acknowledged response       
        DATA_PACKET_START_BYTE    = 0;   %Start of each streamed packet
        STATUS_RESPONSE           = char(hex2dec('71'));
        INSTREAM_CMD_RESPONSE     = char(hex2dec('8A'));
        VBATT_RESPONSE            = char(hex2dec('94')); 


        %Sensors
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

        DEFAULT_TIMEOUT = 8;             % Default timeout for Wait for Acknowledgement response
    end

    properties
        name (1,:) {string};
        bluetoothConn bluetooth;
        isConnected {logical} = false;
        isStreaming {logical} = false;

        LastQuaternion = [0.5, 0.5, 0.5, 0.5];              % Last estimated quaternion value, used to incrementally update quaternion.
        SerialDataOverflow = [];                            % Feedback buffer used by the framepackets method

        SignalNameArray;                                    % Cell array contain the names of the enabled sensor signals in string format
        SignalDataTypeArray;                                % Cell array contain the names of the sensor signal datatypes in string format
        nBytesDataPacket;                                   % Unsigned integer value containing the size of a data packet for the Shimmer in its current setting

        SamplingRate = 'Nan';                               % Numerical value defining the sampling rate of the Shimmer
        EnabledSensors;

        % Enable PC Timestamps
        EnableTimestampUnix = 1;
        LastSampleSystemTimeStamp = 0;

        Orientation3D = 1;                                  % Enable/disable 3D orientation, i.e. get quaternions in getdata

        GyroInUseCalibration = 0;                           % Enable/disable gyro in-use calibration
        GyroBufferSize = 100;                               % Buffer size (samples)
        GyroBuffer;                                         % Buffer for gyro in-use calibration
        GyroMotionThreshold = 1.2;                          % Threshold for detecting motion

        GetADCFlag = 0;                                     % Flag for getdata/getadcdata

        LatestBatteryVoltageReading = 'Nan'; 
        GsrRange='Nan';                                     % Numerical value defining the gsr range of the Shimmer
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

        function isAcknowledged = waitForAck(thisShimmer, timeout)
            % Reads serial data buffer until either an acknowledgement is
            % received or time out from input timeout is exceeded.
            serialData = [];
            timeCount = 0;
            waitPeriod = 0.1;                                              % Period in seconds the while loop waits between iterations
            
            elapsedTime = 0;                                               % Reset to 0
            tic;                                                           % Start timer
            
            while (isempty(serialData) && (elapsedTime < timeout))         % Keep reading serial port data until new data arrives OR elapsedTime exceeds timeout
                [serialData] = read(thisShimmer.bluetoothConn, 1); % Read a single byte of serial data from the com port
                pause(waitPeriod);                                         % Wait 0.1 of a second
                timeCount = timeCount + waitPeriod;                        % Timeout is used to exit while loop after 5 seconds
                
                elapsedTime = elapsedTime + toc;                           % Stop timer and add to elapsed time
                tic;                                                       % Start timer
                
            end
            
            elapsedTime = elapsedTime + toc;                               % Stop timer
            
            if (not(isempty(serialData)))                                  % TRUE if a byte value was received
                if serialData(1) == thisShimmer.ACK_RESPONSE               % TRUE if the byte value was the acknowledge command
                    isAcknowledged = true;
                else
                    isAcknowledged = false;
                end
            else
                isAcknowledged = false;
                fprintf(strcat('Warning: waitforack - Timed-out on wait for acknowledgement byte on Shimmer COM',thisShimmer.name,'.\n'));
            end
            
        end %function waitforack

        %Start streaming
        function startedStreaming = startStreaming(thisShimmer)
            startedStreaming = false;

            if (thisShimmer.isConnected && ~thisShimmer.isStreaming)
                flush(thisShimmer.bluetoothConn);
                write(thisShimmer.bluetoothConn, thisShimmer.START_STREAMING_COMMAND);
                
                startedStreaming = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);
                thisShimmer.isStreaming = startedStreaming;
            end
        end

        %Stop streaming
        function stoppedStreaming = stopStreaming(thisShimmer)
            stoppedStreaming = false;

            if (thisShimmer.isConnected && thisShimmer.isStreaming)
                flush(thisShimmer.bluetoothConn);
                write(thisShimmer.bluetoothConn, thisShimmer.STOP_STREAMING_COMMAND);
   
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
               
                write(thisShimmer.bluetoothConn, thisShimmer.SET_SENSORS_COMMAND);
                write(thisShimmer.bluetoothConn, char(enabledSensorsLowByte));           % Write the enabled sensors lower byte value to the Shimmer
                write(thisShimmer.bluetoothConn, char(enabledSensorsHighByte));          % Write the enabled sensors higher byte value to the Shimmer
                write(thisShimmer.bluetoothConn, char(enabledSensorsHigherByte));        % Write the enabled sensors higher byte value to the Shimmer

                areEnabled = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);
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
            thisShimmer.EnabledSensors = enabledSensors;
        end   
    
        % Disables conflicting sensors based on input enabledSensors.
        function enabledSensors = disableunavailablesensors(thisShimmer, enabledSensors)
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

        function quaternionData = updateQuaternion(thisShimmer, accelCalibratedData, gyroCalibratedData, magCalibratedData)
            % Updates quaternion data based on accelerometer, gyroscope and
            % magnetometer data inputs: accelCalibratedData,
            % gyroCalibratedData and magCalibratedData.
            %
            % Implementation of MARG algorithm from:
            % Madgwick, S.O.H.; Harrison, A. J L; Vaidyanathan, R., "Estimation of IMU and MARG orientation using a gradient descent algorithm,"
            % Rehabilitation Robotics (ICORR), 2011 IEEE International Conference on , vol., no., pp.1,7, June 29 2011-July 1 2011, doi: 10.1109/ICORR.2011.5975346
            
            numSamples = size(accelCalibratedData,1);
            quaternionData = zeros(numSamples,4);
            
            % Normalise accelerometer and magnetometer data.
            accelMagnitude = sqrt(sum(accelCalibratedData.^2,2));
            magMagnitude = sqrt(sum(magCalibratedData.^2,2));
            
            if(min(accelMagnitude) ~= 0 && min(magMagnitude) ~= 0)
                accelNormalised = accelCalibratedData./repmat(accelMagnitude,1,3);
                magNormalised = magCalibratedData./repmat(magMagnitude,1,3);
                
                previousQuaternion = thisShimmer.LastQuaternion;
                
                iSample = 1;
                
                while(iSample <= numSamples)
                    q1 = previousQuaternion(1);
                    q2 = previousQuaternion(2);
                    q3 = previousQuaternion(3);
                    q4 = previousQuaternion(4);
                    
                    ax = accelNormalised(iSample,1);
                    ay = accelNormalised(iSample,2);
                    az = accelNormalised(iSample,3);
                    mx = magNormalised(iSample,1);
                    my = magNormalised(iSample,2);
                    mz = magNormalised(iSample,3);
                    gx = gyroCalibratedData(iSample,1)/180*pi;
                    gy = gyroCalibratedData(iSample,2)/180*pi;
                    gz = gyroCalibratedData(iSample,3)/180*pi;
                    
                    q1q1 = q1*q1;
                    q2q2 = q2*q2;
                    q3q3 = q3*q3;
                    q4q4 = q4*q4;
                    
                    twoq1 = 2*q1;
                    twoq2 = 2*q2;
                    twoq3 = 2*q3;
                    twoq4 = 2*q4;
                    
                    q1q2 = q1*q2;
                    q1q3 = q1*q3;
                    q1q4 = q1*q4;
                    q2q3 = q2*q3;
                    q2q4 = q2*q4;
                    q3q4 = q3*q4;
                    
                    % Calculate reference direction of Earth's magnetic
                    % field.
                    hx = mx*(q1q1 + q2q2 - q3q3-q4q4) + 2*my*(q2q3 - q1q4) + 2*mz*(q2q4 + q1q3);
                    hy = 2*mx*(q1q4 + q2q3) + my*(q1q1 - q2q2 + q3q3 - q4q4) * 2*mz*(q3q4 - q1q2);
                    twobx = sqrt(hx^2 + hy^2); % horizontal component
                    twobz = 2*mx*(q2q4 - q1q3) + 2*my*(q1q2 + q3q4) + mz*(q1q1 - q2q2 - q3q3 + q4q4); % vertical component
                    
                    % Calculate corrective step for gradient descent
                    % algorithm.
                    s1 = -twoq3 * (2*(q2q4 - q1q3) - ax) + ...
                        twoq2*(2*(q1q2 + q3q4) - ay) - ...
                        twobz*q3*(twobx*(0.5 - q3q3 - q4q4) + twobz*(q2q4 - q1q3) - mx) + ...
                        (-twobx*q4 + twobz*q2)*(twobx*(q2q3 - q1q4) + twobz*(q1q2 + q3q4) - my) + ...
                        twobx*q3*(twobx*(q1q3 + q2q4) + twobz*(0.5 - q2q2 - q3q3) - mz);
                    
                    s2 = twoq4*(2*(q2q4 - q1q3) - ax) + ...
                        twoq1*(2*(q1q2 + q3q4) - ay) - ...
                        4*q2*(1 - 2*(q2q2 + q3q3) - az) + ...
                        twobz*q4*(twobx*(0.5 - q3q3 - q4q4) + twobz*(q2q4 - q1q3) - mx) + ...
                        (twobx*q3 + twobz*q1)*(twobx*(q2q3 - q1q4) + twobz*(q1q2 + q3q4) - my) + ...
                        (twobx*q4 - twobz*twoq2)*(twobx*(q1q3 + q2q4) + twobz*(0.5 - q2q2 - q3q3) - mz);
                    
                    s3 = -twoq1*(2*(q2q4 - q1q3) - ax) + ...
                        twoq4*(2*(q1q2 + q3q4) - ay) - ...
                        4*q3*(1 - 2*(q2q2 + q3q3) - az) + ...
                        (-twobx*twoq3 - twobz*q1)*(twobx*(0.5 - q3q3 - q4q4) + twobz*(q2q4 - q1q3) - mx) + ...
                        (twobx * q2 + twobz * q4)*(twobx*(q2q3 - q1q4) + twobz*(q1q2 + q3q4) - my) + ...
                        (twobx * q1 - twobz*twoq3)*(twobx*(q1q3 + q2q4) + twobz*(0.5 - q2q2 - q3q3) - mz);
                    
                    s4 = twoq2 * (2.0 * (q2q4 - q1q3) - ax) + ...
                        twoq3 * (2*(q1q2 + q3q4) - ay) + ...
                        (-twobx * twoq4 + twobz * q2) * (twobx * (0.5 - q3q3 - q4q4) + twobz * (q2q4 - q1q3) - mx) + ...
                        (-twobx * q1 + twobz * q3) * (twobx * (q2q3 - q1q4) + twobz * (q1q2 + q3q4) - my) + ...
                        twobx * q2 * (twobx * (q1q3 + q2q4) + twobz * (0.5 - q2q2 - q3q3) - mz);
                    
                    sNormalised = [s1, s2, s3, s4]/sqrt(sum([s1 s2 s3 s4].^2));
                    
                    % Rate of change from gyro values...
                    dqdt(1) = 0.5 * (-q2 * gx - q3 * gy - q4 * gz);
                    dqdt(2) = 0.5 * ( q1 * gx - q4 * gy + q3 * gz);
                    dqdt(3) = 0.5 * ( q4 * gx + q1 * gy - q2 * gz);
                    dqdt(4) = 0.5 * (-q3 * gx + q2 * gy + q1 * gz);
                    
                    % ...plus rate of change from gradient descent step.
                    beta = 0.5;
                    dqdt = dqdt - beta*sNormalised;
                    
                    tempQuaternion = previousQuaternion + dqdt./thisShimmer.SamplingRate;
                    quaternionData(iSample, :) = tempQuaternion/(sqrt(sum(tempQuaternion.^2)));
                    
                    previousQuaternion = quaternionData(iSample, :);
                    thisShimmer.LastQuaternion = previousQuaternion;
                    iSample = iSample + 1;
                end
            end
            
        end %function updatequaternion

        function [parsedData,systemTime] = capturedata(thisShimmer)
            % Reads data from the serial buffer, frames and parses these data.
            parsedData=[];
            systemTime = 0;
            
            if (thisShimmer.isStreaming)                        % TRUE if the Shimmer is in a Streaming state
                
                serialData = [];
                
                [serialData] = readcell(thisShimmer.bluetoothConn, inf);  % Read all available serial data from the com port
                
                if (not(isempty(serialData)))
                    
                     if (thisShimmer.EnableTimestampUnix)  
                         systemTime = clock;
                     end
                   
                    framedData = framedata(thisShimmer, serialData);
                    parsedData = parsedata(thisShimmer, framedData);
         
                end
            else
                fprintf(strcat('Warning: capturedata - Cannot capture data as COM ',thisShimmer.name,' Shimmer is not Streaming'));
            end
            
        end %function captureData

        function [sensorData,signalName,signalFormat,signalUnit] = getdata(thisShimmer,varargin)
            %GETDATA - Get sensor data from the data buffer and calibrates
            %them depending on user instructions
            %
            %   SENSORDATA = GETDATA returns a 2D array of sensor data from
            %   the data buffer and the corresponding signal names
            %
            %   SYNOPSIS: [sensorData,signalName,signalFormat,signalUnit] = thisShimmer.getdata(dataMode)
            %
            %   INPUT: dataMode - Value defining the DATAMODE where
            %                     DATAMODE = 'a' retrieves data in both calibrated
            %                     and uncalibrated format DATAMODE = 'u'
            %                     retrieves data in uncalibrated format
            %                     DATAMODE = 'c' retrieves data in
            %                     calibrated format.
            %
            %                     Valid values for DATAMODE are 'a', 'c'
            %                     and 'u'.
            %
            %   OUTPUT: sensorData - [m x n] array of sensor data
            %                              read from the data buffer, where
            %                              m = number of data samples and n
            %                              = number of data signals. Output
            %                              will depend on the data mode.
            % 
            %           signalName - a 1 dimensional cell array of the
            %                        signal names. The index of each signal
            %                        name corresponds to the index of the
            %                        sensor data. 
            %
            %           signalFormat - a 1 dimensional cell array of the
            %                        signal names. The index of each signal
            %                        format corresponds to the index of the
            %                        sensor data. 
            %
            %           signalUnit - a 1 dimensional cell array of the
            %                        signal units. The index of each signal
            %                        unit corresponds to the index of the
            %                        sensor data. Signal units end with a
            %                        '*' when default calibration
            %                        parameters are used.
            %
            %
            %   EXAMPLE:  [newData,signalNameArray,signalFormatArray,signalUnitArray] = shimmer1.getdata('c');
            %
            %   See also setenabledsensors getenabledsignalnames
            %   getsignalname getsignalindex getpercentageofpacketsreceived
            
            sensorData=double([]);
            signalName=[];
            signalFormat=[];
            signalUnit=[];
            
            if (nargin > 2)                                                % getdata requires only one argument, dataMode = a, u, or c.
                disp('Warning: getdata - Requires only one argument: dataMode = ''a'', ''u'', or ''c''.');
                disp('Warning: getdata - Getdata has changed since MATLAB ID v2.3;');
                disp('deprecatedgetdata() facilitates backwards compatibility');
            elseif ~(strcmp(varargin{1},'c') || strcmp(varargin{1},'u') || strcmp(varargin{1},'a'))
                disp('Warning: getdata - Valid arguments for getdata = ''a'', ''u'', or ''c''.');
            else
                dataMode = varargin{1};
                [parsedData,systemTime] = capturedata(thisShimmer);
                parsedData = double(parsedData);
                
                if (~isempty(parsedData))
                                    
                    numSignals = length(thisShimmer.SignalNameArray);      % get number of signals from signalNameArray
                                                      
                    s = 1;
                    while s <= numSignals                                 % check signalNameArray for enabled signals
                        if strcmp(thisShimmer.SignalNameArray(s),'Timestamp')
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=gettimestampdata(thisShimmer,dataMode,parsedData); % Time Stamp
                            s = s+1;

                            if (thisShimmer.EnableTimestampUnix && strcmp(dataMode,'c'))
                                thisShimmer.LastSampleSystemTimeStamp = thisShimmer.convertMatlabTimeToUnixTimeMilliseconds(systemTime);
                                nSamp = size(tempData,1);
                                timeStampUnixData = zeros(nSamp,1);
                                timeStampUnixData(nSamp) = thisShimmer.LastSampleSystemTimeStamp;
                                for iUnix = 1:nSamp-1
                                    timeStampUnixData(iUnix,1)=NaN;
                                end
                                timeStampUnixSignalName = 'Time Stamp Unix';
                                timeStampUnixDataSignalFormat = 'CAL';
                                timeStampUnixSignalUnit = 'milliseconds'; 
                                tempData = [tempData timeStampUnixData];
                                tempSignalName = [tempSignalName timeStampUnixSignalName];
                                tempSignalFormat = [tempSignalFormat timeStampUnixDataSignalFormat];
                                tempSignalUnit = [tempSignalUnit timeStampUnixSignalUnit];
                            end
                        elseif strcmp(thisShimmer.SignalNameArray(s),'Low Noise Accelerometer X')
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getlownoiseacceldata(thisShimmer,dataMode,parsedData); % Shimmer3 only
                            s = s+3;            % skip Y and Z
                        elseif strcmp(thisShimmer.SignalNameArray(s),'Battery Voltage') % Shimmer3 battery voltage
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getbattvoltdata(thisShimmer,dataMode,parsedData); %takes average of batt volt data and send a command to change LED if it is reaching low power
                            s = s+1;
                        elseif strcmp(thisShimmer.SignalNameArray(s),'Wide Range Accelerometer X')
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getwiderangeacceldata(thisShimmer,dataMode,parsedData); % Shimmer3 only
                            s = s+3;            % skip Y and Z
                        elseif strcmp(thisShimmer.SignalNameArray(s),'Accelerometer X')
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getacceldata(thisShimmer,dataMode,parsedData);
                            s = s+3;            % skip Y and Z
                        elseif strcmp(thisShimmer.SignalNameArray(s),'Gyroscope X')
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getgyrodata(thisShimmer,dataMode,parsedData);
                            if(thisShimmer.GyroInUseCalibration)
                                if(dataMode == 'u')
                                    thisShimmer.GyroBuffer = [thisShimmer.GyroBuffer; tempData];
                                else
                                    [uncalibratedGyroData,~,~,~] = getgyrodata(thisShimmer,'u',parsedData);
                                    thisShimmer.GyroBuffer = [thisShimmer.GyroBuffer; uncalibratedGyroData];
                                end
                                bufferOverflow = size(thisShimmer.GyroBuffer,1) - thisShimmer.GyroBufferSize;
                                if(bufferOverflow > 0)
                                    thisShimmer.GyroBuffer = thisShimmer.GyroBuffer((bufferOverflow+1):end,:);
                                end
                                if(nomotiondetect(thisShimmer))
                                    estimategyrooffset(thisShimmer); 
                                end
                            end
                            s = s+3;            % skip Y and Z
                        elseif strcmp(thisShimmer.SignalNameArray(s),'Magnetometer X')
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getmagdata(thisShimmer,dataMode,parsedData);
                            s = s+3;            % skip Y and Z
                        elseif strcmp(thisShimmer.SignalNameArray(s),'GSR Raw')   % GSR
                            if(ischar(thisShimmer.GsrRange))
                                disp('Warning: getdata - GSR range undefined, see setgsrrange().');
                            else
                                [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getgsrdata(thisShimmer,dataMode,parsedData);
                                s = s+1;
                            end
                        elseif (strcmp(thisShimmer.SignalNameArray(s),'External ADC A7') || strcmp(thisShimmer.SignalNameArray(s),'External ADC A6') ||...  % Shimmer3 ADCs
                                strcmp(thisShimmer.SignalNameArray(s),'External ADC A15') || strcmp(thisShimmer.SignalNameArray(s),'Internal ADC A1') ||...
                                strcmp(thisShimmer.SignalNameArray(s),'Internal ADC A12') || strcmp(thisShimmer.SignalNameArray(s),'Internal ADC A13') ||...
                                strcmp(thisShimmer.SignalNameArray(s),'Internal ADC A14'))
                             
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getadcdata(thisShimmer,dataMode,parsedData);
                            thisShimmer.GetADCFlag = 1; % Set getadcdata flag so that getadcdata is only called once.
                            s = s + 1;
                        elseif (strcmp(thisShimmer.SignalNameArray(s),'Pressure') || strcmp(thisShimmer.SignalNameArray(s),'Temperature')) % Shimmer3 BMP180/BMP280 pressure and temperature)
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getpressuredata(thisShimmer,dataMode,parsedData);
                            s = s+2;
                        elseif (strcmp(thisShimmer.SignalNameArray(s),'EXG1 STA') || strcmp(thisShimmer.SignalNameArray(s),'EXG2 STA')) % Shimmer3 EXG
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getexgdata(thisShimmer,dataMode,parsedData);
                            if (size(tempData,2) == 2)
                                s = s+size(tempData,2)+1;  % EXG1 or EXG2 enabled.
                            else
                                s = s+size(tempData,2)+2;  % EXG1 and EXG2 enabled.
                            end
                        elseif strcmp(thisShimmer.SignalNameArray(s),'Bridge Amplifier High') % Shimmer3 Bridge Amplifier
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getbridgeamplifierdata(thisShimmer,dataMode,parsedData);
                            s = s+2;
                        elseif strcmp(thisShimmer.SignalNameArray(s),'Strain Gauge High') % Shimmer2r Strain Gauge
                            [tempData,tempSignalName,tempSignalFormat,tempSignalUnit]=getstraingaugedata(thisShimmer,dataMode,parsedData);
                            s = s+2;
                        end
                        sensorData=[sensorData tempData];
                        signalName=[signalName tempSignalName];
                        signalFormat=[signalFormat tempSignalFormat];
                        signalUnit=[signalUnit tempSignalUnit];
                    end
                    if (thisShimmer.Orientation3D && bitand(thisShimmer.EnabledSensors, hex2dec('E0'))>0 && strcmp(dataMode,'c')) % Get Quaternion data if Orientation3D setting and sensors Accel, Gyro and Mag are enabled.
                        [accelData,~,~,~]=getacceldata(thisShimmer,'c',parsedData);
                        [gyroData,~,~,~]=getgyrodata(thisShimmer,'c',parsedData);
                        [magData,~,~,~]=getmagdata(thisShimmer,'c',parsedData);
                        [quaternionData,tempSignalName,tempSignalFormat,tempSignalUnit]=getquaterniondata(thisShimmer,'c',accelData,gyroData,magData);
                        
                        sensorData=[sensorData quaternionData];
                        signalName=[signalName tempSignalName];
                        signalFormat=[signalFormat tempSignalFormat];
                        signalUnit=[signalUnit tempSignalUnit];
                    end
                end
            end
            thisShimmer.GetADCFlag = 0; % Reset getadcdata flag.
        end % function getdata
        
        function unixTimeMilliseconds = convertMatlabTimeToUnixTimeMilliseconds(matlabTime)
            %CONVERTMATLABTIMETOUNIXTIMEMILLISECONDS - converts a MATLAB  
            % date vector or date string to Unix Time in milliseconds.
            %   
            %   UNIXTIMEMILLISECONDS           = CONVERTMATLABTIMETOUNIXTIMEMILLISECONDS(MATLABTIME)
            %                                     converts either a MATLAB date vector 
            %                                     or date string to Unix Time in milliseconds.
            %
            %   SYNOPSIS: unixTimeMilliseconds = thisShimmer.convertMatlabTimeToUnixTimeMilliseconds(matlabTime)
            %
            %   INPUT:    matlabTime           - MATLAB date vector or date string
            %
            %   OUTPUT:   unixTimeMilliseconds - Unix time in milliseconds
            %
            %   See also datenum
            
            unixTimeMilliseconds = 24*3600*1000 * (datenum(matlabTime)-datenum('01-Jan-1970')) - (1*3600*1000); 
        end

        function framedData = framedata(thisShimmer, serialData)
            serialData = cat(1,thisShimmer.SerialDataOverflow,serialData);                              % append serial data from previous function call to new serial data
            framedData = [];
            iDataRow = 1;
            skip = 0;
            indexFirstDataPacket = find(serialData == thisShimmer.DATA_PACKET_START_BYTE,1);            % find first data packet start byte
            indexFirstAckResponse = find(serialData == thisShimmer.ACK_RESPONSE,1);                     % find first ack response byte
            
            if (isempty(indexFirstDataPacket) && isempty(indexFirstAckResponse))                        % check whether data packet start byte or ack response is found first in serial data
                thisShimmer.SerialDataOverflow = serialData;                                            % use serial data in next function call in case no data packet start byte or ack response is found
                framedData = [];
                skip = 1;
            elseif (isempty(indexFirstAckResponse))
                currentIndex = indexFirstDataPacket;                                                    % start at first data packet start byte
                ackFirst = 0;
            elseif (isempty(indexFirstDataPacket) || indexFirstDataPacket > indexFirstAckResponse)
                currentIndex = indexFirstAckResponse;                                                   % start at first ack response byte
                ackFirst = 1;
            else
                currentIndex = indexFirstDataPacket;                                                    % start at first data packet start byte
                ackFirst = 0;
            end
            
            if ~skip
                if ~(ackFirst)                                                                          % data packet start byte is found before ack response is found
                    exitLoop = 0;
                    endOfPacket = 0;
                    while (currentIndex <= length(serialData) && ~exitLoop)                             % loop through serialData
                        if (length(serialData(currentIndex:end)) >= (thisShimmer.nBytesDataPacket))                                                          % check if there are enough bytes for a full packet
                            if (length(serialData(currentIndex:end)) == (thisShimmer.nBytesDataPacket))                                                      % check if there are exactly enough bytes for one packet - it is the last packet
                                framedData(iDataRow,1:thisShimmer.nBytesDataPacket) = serialData(currentIndex:currentIndex-1+thisShimmer.nBytesDataPacket);  % add current packet to framedData
                                currentIndex = length(serialData);
                                endOfPacket = 1;
                            elseif (serialData(currentIndex+thisShimmer.nBytesDataPacket)==thisShimmer.ACK_RESPONSE)                                         % next byte after nBytesDataPacket bytes is 0xFF
                                framedData(iDataRow,1:thisShimmer.nBytesDataPacket) = serialData(currentIndex:currentIndex-1+thisShimmer.nBytesDataPacket);  % add current packet to framedData
                                thisShimmer.SerialDataOverflow = serialData(currentIndex+thisShimmer.nBytesDataPacket:end);                                  % use serial data in next function call
                                exitLoop = 1;                                                                                                                % exit while loop
                            elseif (serialData(currentIndex+thisShimmer.nBytesDataPacket)==thisShimmer.DATA_PACKET_START_BYTE)                               % next byte after nBytesDataPacket bytes is 0x00
                                framedData(iDataRow,1:thisShimmer.nBytesDataPacket) = serialData(currentIndex:currentIndex-1+thisShimmer.nBytesDataPacket);  % add current packet to framedData
                                currentIndex = currentIndex+thisShimmer.nBytesDataPacket;                                                                    % update index to next data packet start byte
                                iDataRow = iDataRow + 1;
                            else                                                                        % error, discard first byte and pass rest to overflow - not last packet and first byte after nBytesDataPacket is not 0x00 or 0xFF
                                thisShimmer.SerialDataOverflow = serialData(currentIndex+1:end);        % use serial data - apart from first byte - in next function call
                                exitLoop = 1;                                                           % exit while loop
                            end
                        else                                                                            % not enough bytes for a full packet
                            if (endOfPacket)
                                thisShimmer.SerialDataOverflow = [];                                    % all serial data is used in current function call
                            else
                                thisShimmer.SerialDataOverflow = serialData(currentIndex:end);          % use serial data in next function call
                            end
                            exitLoop = 1;                                                               % exit while loop
                        end
                    end
                else                                                                                    % ack response byte is found before data packet start byte is found
                    if (currentIndex == length(serialData))
                        thisShimmer.SerialDataOverflow = serialData(currentIndex:end);                  % use serial data in next function call
                    elseif (serialData(currentIndex+1) == thisShimmer.ACK_RESPONSE)                     % check if next byte is also acknowledgement byte
                        thisShimmer.SerialDataOverflow = serialData(currentIndex+1:end);                % discard acknowledgement byte and pass rest to overflow for next function call
                    elseif (serialData(currentIndex+1) == thisShimmer.DATA_PACKET_START_BYTE)           % check if next byte is data start byte
                        thisShimmer.SerialDataOverflow = serialData(currentIndex+1:end);                % discard acknowledgement byte and pass rest to overflow for next function call
                    elseif (serialData(currentIndex+1) ==  thisShimmer.INSTREAM_CMD_RESPONSE)
                        if (currentIndex <= length(serialData(currentIndex:end))-3)                     % check if enough bytes for a response
                            if (serialData(currentIndex+2) ==  thisShimmer.STATUS_RESPONSE)
                                thisShimmer.SerialDataOverflow = serialData(currentIndex+4:end);        % pass rest of bytes to overflow
                            elseif (serialData(currentIndex+2) ==  thisShimmer.VBATT_RESPONSE)
                                
                                if (currentIndex <= length(serialData(currentIndex:end))-3-2)      % check if enough bytes for full response
                                    battAdcValue = uint32(uint16(serialData(currentIndex+3+1))*256 + uint16(serialData(currentIndex+3)));                % battery ADC value
                                    batteryVoltage = calibrateu12ADCValue(thisShimmer,battAdcValue,0,3.0,1.0)*1.988; % calibrate 12-bit ADC value with offset = 0; vRef=3.0; gain=1.0
                                    fprintf(['Battery Voltage: ' num2str(batteryVoltage) '[mV]' '\n']);
                                    thisShimmer.LatestBatteryVoltageReading = batteryVoltage;
                                    thisShimmer.SerialDataOverflow = serialData(currentIndex+5+1:end);        % pass rest of bytes to overflow
                                else                                                                    % not enough bytes to get the full directory name
                                    thisShimmer.SerialDataOverflow = serialData(currentIndex:end);      % discard acknowledgement byte and pass rest to overflow for next function call
                                end
                                
                            else                                                                        % (0xFF, 0x8A, ~0x71 && ~0x88)
                                thisShimmer.SerialDataOverflow = serialData(currentIndex+1:end);        % discard acknowledgement byte and pass rest to overflow for next function call
                            end
                        else                                                                            % not enough bytes for full response
                            thisShimmer.SerialDataOverflow = serialData(currentIndex:end);              % discard acknowledgement byte and pass rest to overflow for next function call
                        end
                    else                                                                                % is not last byte, 0xFF, 0x00, 0x8A - assume error occurred - discard first byte and pass rest to overflow for next function call
                        thisShimmer.SerialDataOverflow = serialData(currentIndex+1:end);                % discard acknowledgement byte and pass rest to overflow for next function call
                    end
                end
            end
        end % function framedata
                
        function parsedData = parsedata(thisShimmer, framedData)
            % Parses framed data from input framedData.
            if ~isempty(framedData)                                       % TRUE if framedData is not empty
                
                iColFramedData=2;                                         % Start at 2nd column, 1st colum is data packet identifier
                
                for iColParsedData=1:length(thisShimmer.SignalDataTypeArray)
                    
                    dataType=char(thisShimmer.SignalDataTypeArray(iColParsedData));
                    
                    switch dataType
                        case('u24')
                            lsbArray(:,1) = uint32(framedData(:,iColFramedData + 0));                % Extract the least significant byte and convert to unsigned 32bit
                            msbArray(:,1) = uint32(256*uint32(framedData(:,iColFramedData + 1)));    % Extract the most significant byte and convert to unsigned 32bit
                            xmsbArray(:,1)= uint32(65536*uint32(framedData(:,iColFramedData + 2)));  % Extract the most significant byte and convert to unsigned 32bit
                            parsedData(:,iColParsedData) = int32(xmsbArray+uint32(msbArray) + uint32(lsbArray));  % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 3;                                     % Increment column offset by 3 bytes for next column of sensor data                           
                        case('u8')
                            lsbArray(:,1) = uint8(framedData(:,iColFramedData));                     % Extract the column of bytes of interest
                            parsedData(:,iColParsedData) = int32(lsbArray);                          % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 1;                                     % Increment column offset by 1 byte for next column of sensor data
                        case('i8')
                            lsbArray(:,1) = int8(framedData(:,iColFramedData));                      % Extract the column of bytes of interest
                            parsedData(:,iColParsedData) = int32(lsbArray);                          % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 1;                                     % Increment column offset by 1 byte for next column of sensor data
                        case('u12')
                            lsbArray(:,1) = uint16(framedData(:,iColFramedData));                    % Extract the least significant byte and convert to unsigned 16bit
                            msbArray(:,1) = uint16(bitand(15,framedData(:,iColFramedData + 1)));     % Extract the most significant byte, set 4 MSBs to 0 and convert to unsigned 16bit
                            parsedData(:,iColParsedData) = int32(256*msbArray + lsbArray);           % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 2;                                     % Increment column offset by 2 bytes for next column of sensor data
                        case('u16')
                            lsbArray(:,1) = uint16(framedData(:,iColFramedData));                    % Extract the least significant byte and convert to unsigned 16bit
                            msbArray(:,1) = uint16(framedData(:,iColFramedData + 1));                % Extract the most significant byte and convert to unsigned 16bit
                            parsedData(:,iColParsedData) = int32(256*msbArray + lsbArray);           % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 2;                                     % Increment column offset by 2 bytes for next column of sensor data
                        case('u16*')
                            lsbArray(:,1) = uint16(framedData(:,iColFramedData + 1));                % Extract the least significant byte and convert to unsigned 16bit
                            msbArray(:,1) = uint16(framedData(:,iColFramedData + 0));                % Extract the most significant byte and convert to unsigned 16bit
                            parsedData(:,iColParsedData) = int32(256*msbArray + lsbArray);           % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 2;      
                        case('i16')
                            lsbArray(:,1) = uint16(framedData(:,iColFramedData));                    % Extract the least significant byte and convert to unsigned 16bit
                            msbArray(:,1) = uint16(framedData(:,iColFramedData + 1));                % Extract the most significant byte and convert to unsigned 16bit
                            parsedData(:,iColParsedData) = int32(256*msbArray + lsbArray);           % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 2;                                     % Increment column offset by 2 bytes for next column of sensor data
                            parsedData(:,iColParsedData) = calculatetwoscomplement(thisShimmer,cast(parsedData(:,iColParsedData),'uint16'),16);
                        case('i16*')
                            lsbArray(:,1) = uint16(framedData(:,iColFramedData+1));                  % Extract the least significant byte and convert to unsigned 16bit
                            msbArray(:,1) = uint16(framedData(:,iColFramedData));                    % Extract the most significant byte and convert to unsigned 16bit
                            parsedData(:,iColParsedData) = int32(256*msbArray + lsbArray);           % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 2;                                     % Increment column offset by 2 bytes for next column of sensor data
                            parsedData(:,iColParsedData) = calculatetwoscomplement(thisShimmer,cast(parsedData(:,iColParsedData),'uint16'),16);
                        case('i16>') % int16 to 12 bits
                            lsbArray(:,1) = uint16(framedData(:,iColFramedData));                    % Extract the least significant byte and convert to unsigned 16bit
                            msbArray(:,1) = uint16(framedData(:,iColFramedData + 1));                % Extract the most significant byte and convert to unsigned 16bit
                            parsedData(:,iColParsedData) = int32(256*msbArray + lsbArray);           % Convert to signed 32bit integer to enable creation of array of all data
                            iColFramedData = iColFramedData + 2;                                     % Increment column offset by 2 bytes for next column of sensor data
                            parsedData(:,iColParsedData) = calculatetwoscomplement(thisShimmer,cast(parsedData(:,iColParsedData),'uint16'),16);
                            parsedData(:,iColParsedData) = parsedData(:,iColParsedData)/16;
                        case('u24*') %bytes reverse order
                            lsbArray(:,1) = uint32(framedData(:,iColFramedData + 2));                % Extract the least significant byte and convert to unsigned 32bit
                            msbArray(:,1) = uint32(256*uint32(framedData(:,iColFramedData + 1)));    % Extract the most significant byte and convert to unsigned 32bit
                            xmsbArray(:,1)= uint32(65536*uint32(framedData(:,iColFramedData + 0)));  % Extract the most significant byte and convert to unsigned 32bit
                            parsedData(:,iColParsedData) = int32(xmsbArray+uint32(msbArray) + uint32(lsbArray));
                            iColFramedData = iColFramedData + 3;
                        case('i24*') 
                            lsbArray(:,1) = uint32(framedData(:,iColFramedData + 2));                % Extract the least significant byte and convert to unsigned 32bit
                            msbArray(:,1) = uint32(256*uint32(framedData(:,iColFramedData + 1)));    % Extract the most significant byte and convert to unsigned 32bit
                            xmsbArray(:,1)= uint32(65536*uint32(framedData(:,iColFramedData + 0)));  % Extract the most significant byte and convert to unsigned 32bit
                            parsedData(:,iColParsedData) = uint32(xmsbArray+uint32(msbArray) + uint32(lsbArray));  % Convert to signed 32bit integer to enable creation of array of all data
                            parsedData(:,iColParsedData) = calculatetwoscomplement(thisShimmer,cast(parsedData(:,iColParsedData),'uint32'),24);
                            iColFramedData = iColFramedData + 3;                                     % Increment column offset by 2 bytes for next column of sensor data
                    end
                end
                
            else
                parsedData = [];                                                                     % Return empty array
            end
        end % function parsedata
    end
end