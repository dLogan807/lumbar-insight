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
        nBytesDataPacket = 22;           %MUST BE CHANGED MANUALLY

        DEFAULT_TIMEOUT = 8;             % Default timeout for Wait for Acknowledgement response
    end

    properties
        name (1,:) {string};
        bluetoothConn bluetooth;
        isConnected {logical} = false;
        isStreaming {logical} = false;

        LastQuaternion = [0.5, 0.5, 0.5, 0.5];              % Last estimated quaternion value, used to incrementally update quaternion.
        SerialDataOverflow = [];                            % Feedback buffer used by the framepackets method

        SamplingRate = 'Nan';                               % Numerical value defining the sampling rate of the Shimmer
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

        function quaternionData = updatequaternion(thisShimmer, accelCalibratedData, gyroCalibratedData, magCalibratedData)
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
    end
end