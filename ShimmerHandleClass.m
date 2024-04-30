% Code modified from the official Instrumentation Driver.
% Shimmer. (2022). Shimmer Matlab Instrumentation Driver. https://github.com/ShimmerEngineering/Shimmer-MATLAB-ID
% No Shimmer 2/2r support. Only supports 9DOF (IMU) daughter board and assumes latest Shimmer3 firmware.
% Reduced functionality due to time constraints and project goals.

classdef ShimmerHandleClass < handle
    %Class to interface with a Shimmer3 device over bluetooth
    
    properties (Constant = true, Access = private)
        %Commands
        INQUIRY_COMMAND           = 0x01;
        SET_SENSORS_COMMAND       = 0x08;
        START_STREAMING_COMMAND   = 0x07;
        STOP_STREAMING_COMMAND    = 0x20;
        GET_ACCEL_RANGE_COMMAND   = char(11);                              % Get accelerometer range command sent to the shimmer in order to receive the accelerometer range response
        GET_CONFIG_BYTE0_COMMAND  = char(16);                              % Get config byte0 command sent to the shimmer in order to receive the config byte0 response (Get config bytes byte0, byte1, byte2, byte3 For Shimmer3.) 
        SET_ACCEL_RANGE_COMMAND   = char(9);                               % First byte sent to the shimmer when implementing a set accelerometer range operation, it is followed by the byte value defining the setting
        GET_SAMPLING_RATE_COMMAND = char(3);                               % Get sampling rate command sent to the shimmer in order to receive the sampling rate response
        SET_SAMPLING_RATE_COMMAND = char(5);                               % First byte sent to the shimmer when implementing a set sampling rate operation, it is followed by the byte value defining the setting
        SET_LSM303DLHC_ACCEL_SAMPLING_RATE_COMMAND = char(hex2dec('40'));  % Only available for Shimmer3 
        SET_MPU9150_SAMPLING_RATE_COMMAND = char(hex2dec('4C'));
        SET_MAG_SAMPLING_RATE_COMMAND    = char(hex2dec('3A'));
        GET_EXG_REGS_COMMAND = char(hex2dec('63'));
        SET_EXG_REGS_COMMAND = char(hex2dec('61'));

        %Responses
        ACK_RESPONSE              = 255;                                   %Shimmer acknowledged response       
        DATA_PACKET_START_BYTE    = 0;                                     %Start of each streamed packet
        STATUS_RESPONSE           = char(hex2dec('71'));
        INSTREAM_CMD_RESPONSE     = char(hex2dec('8A'));
        VBATT_RESPONSE            = char(hex2dec('94'));
        INQUIRY_RESPONSE          = 0x02;
        ACCEL_RANGE_RESPONSE      = newline;                               % First byte value received from the shimmer in the accel range response, it is followed by the byte value defining the setting
        CONFIG_BYTE0_RESPONSE     = char(15);                              % First byte value received from the shimmer in the config byte0 response, it is followed by the byte value defining the setting
        SAMPLING_RATE_RESPONSE    = char(4);                               % First byte value received from the shimmer in the sampling rate response, it is followed by the byte value defining the setting
        EXG_REGS_RESPONSE = char(hex2dec('62'));

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

    properties (Access = private)
        bluetoothConn bluetooth;

        % Calibration properties
        % ACCEL Calibration
        DefaultAccelCalibrationParameters=true;
        DefaultDAccelCalibrationParameters=true;
        AccelCalParametersOV=[2048;2048;2048];                             
        AccelCalParametersSM=[101 0 0; 0 101 0; 0 0 101];
        AccelCalParametersAM=[-1 0 0; 0 -1 0; 0 0 1];   
        % Needed to store calibration values of Digital Accel
        DAccelCalParametersOV=[0;0;0];                           
        DAccelCalParametersSM=[1631 0 0; 0 1631 0; 0 0 1631]; 
        DAccelCalParametersAM=[-1 0 0; 0 1 0; 0 0 -1];   

        % Accel Calibration Default Values for Shimmer3
        AccelLowNoiseCalParametersSM2gShimmer3=[83 0 0; 0 83 0; 0 0 83];           % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (2g))  - KXRB5-2042
        AccelLowNoiseCalParametersSM2gShimmer3_2=[92 0 0; 0 92 0; 0 0 92];         % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (2g))  - KXTC9-2050
        AccelWideRangeCalParametersSM2gShimmer3=[1631 0 0; 0 1631 0; 0 0 1631];    % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (2g))  - LSM303DLHC
        AccelWideRangeCalParametersSM4gShimmer3=[815 0 0; 0 815 0; 0 0 815];       % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (4g))  - LSM303DLHC
        AccelWideRangeCalParametersSM8gShimmer3=[408 0 0; 0 408 0; 0 0 408];       % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (8g))  - LSM303DLHC
        AccelWideRangeCalParametersSM16gShimmer3=[135 0 0; 0 135 0; 0 0 135];      % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (16g)) - LSM303DLHC
        AccelWideRangeCalParametersSM2gShimmer3_2=[1671 0 0; 0 1671 0; 0 0 1671];  % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (2g))  - LSM303AHTR
        AccelWideRangeCalParametersSM4gShimmer3_2=[836 0 0; 0 836 0; 0 0 836];     % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (4g))  - LSM303AHTR
        AccelWideRangeCalParametersSM8gShimmer3_2=[418 0 0; 0 418 0; 0 0 418];     % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (8g))  - LSM303AHTR
        AccelWideRangeCalParametersSM16gShimmer3_2=[209 0 0; 0 209 0; 0 0 209];    % Default Calibration Parameters for Accelerometer (Sensitivity Matrix (16g)) - LSM303AHTR
        AccelLowNoiseCalParametersOVShimmer3=[2047;2047;2047];                     % KXRB5-2042
        AccelLowNoiseCalParametersOVShimmer3_2=[2253;2253;2253];                   % KXTC9-2050
        AccelWideRangeCalParametersOVShimmer3=[0;0;0];                             % LSM303DLHC/LSM303AHTR
        AccelLowNoiseCalParametersAMShimmer3=[0 -1 0; -1 0 0; 0 0 -1];             % KXRB5-2042/KXTC9-2050
        AccelWideRangeCalParametersAMShimmer3=[-1 0 0; 0 1 0; 0 0 -1];             % LSM303DLHC
        AccelWideRangeCalParametersAMShimmer3_2=[0 -1 0; 1 0 0; 0 0 -1];           % LSM303AHTR
        
        % GYRO Calibration
        DefaultGyroCalibrationParameters=true;
        GyroCalParametersOV=[0;0;0];                              
        GyroCalParametersSM=[2.73 0 0; 0 2.73 0; 0 0 2.73];                
        GyroCalParametersAM=[0 -1 0; -1 0 0; 0 0 -1];                      
        % Gyro Calibration Default Values for Shimmer3
        GyroCalParametersOVShimmer3=[0;0;0];                               % Default Calibration Parameters for Gyroscope (Offset Vector)
        GyroCalParametersSM2000dpsShimmer3=[16.4 0 0; 0 16.4 0; 0 0 16.4]; % Default Calibration Parameters for Gyroscope (Sensitivity Matrix)
        GyroCalParametersSM1000dpsShimmer3=[32.8 0 0; 0 32.8 0; 0 0 32.8]; % Default Calibration Parameters for Gyroscope (Sensitivity Matrix)
        GyroCalParametersSM500dpsShimmer3=[65.5 0 0; 0 65.5 0; 0 0 65.5];  % Default Calibration Parameters for Gyroscope (Sensitivity Matrix)
        GyroCalParametersSM250dpsShimmer3=[131 0 0; 0 131 0; 0 0 131];     % Default Calibration Parameters for Gyroscope (Sensitivity Matrix)
        GyroCalParametersAMShimmer3=[0 -1 0; -1 0 0; 0 0 -1];              % Default Calibration Parameters for Gyroscope (Alignment Matrix)
        
        %MAG Calibration
        DefaultMagneCalibrationParameters=true;
        MagneCalParametersOV=[0;0;0];                                      
        MagneCalParametersSM=[580 0 0;0 580 0;0 0 580];                    
        MagneCalParametersAM=[1 0 0; 0 1 0; 0 0 -1];                       
        % Mag Calibration Default Values for Shimmer3
        MagneCalParametersOVShimmer3=[0;0;0];                              % Default Calibration Parameters for Magnetometer (Offset Vector)      - LSM303DLHC/LSM303AHTR
        MagneCalParametersSM1_3gaussShimmer3=[1100 0 0;0 1100 0;0 0 980];  % Default Calibration Parameters for Magnetometer (Sensitivity Matrix) - LSM303DLHC
        MagneCalParametersSM1_9gaussShimmer3=[855 0 0;0 855 0;0 0 760];    % Default Calibration Parameters for Magnetometer (Sensitivity Matrix) - LSM303DLHC
        MagneCalParametersSM2_5gaussShimmer3=[670 0 0;0 670 0;0 0 600];    % Default Calibration Parameters for Magnetometer (Sensitivity Matrix) - LSM303DLHC
        MagneCalParametersSM4_0gaussShimmer3=[450 0 0;0 450 0;0 0 400];    % Default Calibration Parameters for Magnetometer (Sensitivity Matrix) - LSM303DLHC
        MagneCalParametersSM4_7gaussShimmer3=[400 0 0;0 400 0;0 0 355];    % Default Calibration Parameters for Magnetometer (Sensitivity Matrix) - LSM303DLHC
        MagneCalParametersSM5_6gaussShimmer3=[330 0 0;0 330 0;0 0 295];    % Default Calibration Parameters for Magnetometer (Sensitivity Matrix) - LSM303DLHC
        MagneCalParametersSM8_1gaussShimmer3=[230 0 0;0 230 0;0 0 205];    % Default Calibration Parameters for Magnetometer (Sensitivity Matrix) - LSM303DLHC
        MagneCalParametersSM49_2gaussShimmer3=[667 0 0;0 667 0;0 0 667];   % Default Calibration Parameters for Magnetometer (Sensitivity Matrix) - LSM303DLHC
        MagneCalParametersAMShimmer3=[-1 0 0; 0 1 0; 0 0 -1];              % Default Calibration Parameters for Magnetometer (Alignment Matrix)   - LSM303DLHC
        MagneCalParametersAMShimmer3_2=[0 -1 0; 1 0 0; 0 0 -1];            % Default Calibration Parameters for Magnetometer (Alignment Matrix)   - LSM303AHTR

        %Data properties
        LastQuaternion = [0.5, 0.5, 0.5, 0.5];              % Last estimated quaternion value, used to incrementally update quaternion.
        SerialDataOverflow = [];                            % Feedback buffer used by the framepackets method

        SignalNameArray;                                    % Cell array contain the names of the enabled sensor signals in string format
        SignalDataTypeArray;                                % Cell array contain the names of the sensor signal datatypes in string format
        nBytesDataPacket;                                   % Unsigned integer value containing the size of a data packet for the Shimmer in its current setting

        %Config properties
        BufferSize = 1;                                     % Not currently used

        SamplingRate = 'Nan';                               % Numerical value defining the sampling rate of the Shimmer
        ConfigByte0;                                        % The current value of the config byte0 setting on the Shimmer
        ConfigByte1;                                        % The current value of the config byte1 setting on the Shimmer3
        ConfigByte2;                                        % The current value of the config byte2 setting on the Shimmer3
        ConfigByte3;                                        % The current value of the config byte3 setting on the Shimmer3

        AccelRange='Nan';                                   % Numerical value defining the accelerometer range of the Shimmer
        AccelWideRangeDataRate='Nan';
        AccelWideRangeHRMode = 'Nan';                       % High Resolution mode LSM303DLHC/LSM303AHTR
        AccelWideRangeLPMode = 'Nan';                       % Low Power mode LSM303DLHC/LSM303AHTR
        MagRange='Nan';                                     % Numerical value defining the mag range of the Shimmer
        GyroRange='Nan';                                    % Numerical value defining the gyro range of the Shimmer
        MagRate='Nan';                                      % Numerical value defining the mag rate of the Shimmer
        InternalExpPower='Nan';                             % Numerical value defining the internal exp power for the Shimmer3
        GyroRate='Nan';
        PressureResolution='Nan';
        EnabledSensors;

        %SHIMMER3 ExG Configurations
        %ExG chip1
        EXG1Config1 = 'Nan';
        EXG1Config2 = 'Nan';
        EXG1Loff = 'Nan';
        EXG1Ch1Set = 'Nan';
        EXG1Ch2Set = 'Nan';
        EXG1RLD_Sens = 'Nan';
        EXG1LOFF_Sens = 'Nan';
        EXG1LOFF_Stat = 'Nan';
        EXG1Resp1 = 'Nan';
        EXG1Resp2 = 'Nan';
        EXG1CH1Gain = 'Nan';
        EXG1CH2Gain = 'Nan';
        EXG1Rate = 'Nan'; 
        EXG1PDB_LOFF_COMP = 'Nan'; % Lead-off comparator power-down
        EXG1FLEAD_OFF = 'Nan'; % Lead-off frequency 
        EXG1RLD_LOFF_SENSE = 'Nan'; % RLD lead-off sense function
        EXG1LOFF2N = 'Nan'; % Channel 2 lead-off detection negative inputs
        EXG1LOFF2P = 'Nan'; % Channel 2 lead-off detection positive inputs
        EXG1LOFF1N = 'Nan'; % Channel 1 lead-off detection negative inputs
        EXG1LOFF1P = 'Nan'; % Channel 1 lead-off detection positive inputs
        EXG1PD1 = 'Nan'; % Channel 1 power-down
        EXG1PD2 = 'Nan'; % Channel 2 power-down
        EXG1ILEAD_OFF = 'Nan'; % Lead-off current magnitude
        EXG1COMP_TH = 'Nan'; % Lead-off comparator threshold
        
        %ExG chip2
        EXG2Config1 = 'Nan';
        EXG2Config2 = 'Nan';
        EXG2Loff = 'Nan';
        EXG2Ch1Set = 'Nan';
        EXG2Ch2Set = 'Nan';
        EXG2RLD_Sens = 'Nan';
        EXG2LOFF_Sens = 'Nan';
        EXG2LOFF_Stat = 'Nan';
        EXG2Resp1 = 'Nan';
        EXG2Resp2 = 'Nan';
        EXG2CH1Gain = 'Nan';
        EXG2CH2Gain = 'Nan';
        EXG2Rate = 'Nan';  
        EXG2PDB_LOFF_COMP = 'Nan'; % Lead-off comparator power-down
        EXG2FLEAD_OFF = 'Nan'; % Lead-off frequency 
        EXG2RLD_LOFF_SENSE = 'Nan'; % RLD lead-off sense function
        EXG2LOFF2N = 'Nan'; % Channel 2 lead-off detection negative inputs
        EXG2LOFF2P = 'Nan'; % Channel 2 lead-off detection positive inputs
        EXG2LOFF1N = 'Nan'; % Channel 1 lead-off detection negative inputs
        EXG2LOFF1P = 'Nan'; % Channel 1 lead-off detection positive inputs
        EXG2PD1 = 'Nan'; % Channel 1 power-down
        EXG2PD2 = 'Nan'; % Channel 2 power-down
        EXG2ILEAD_OFF = 'Nan'; % Lead-off current magnitude
        EXG2COMP_TH = 'Nan'; % Lead-off comparator threshold

        % Enable PC Timestamps
        EnableTimestampUnix = 0;
        LastSampleSystemTimeStamp = 0;

        Orientation3D = 1;                                  % Enable/disable 3D orientation, i.e. get quaternions in getdata

        GyroInUseCalibration = 1;                           % Enable/disable gyro in-use calibration
        GyroBufferSize = 100;                               % Buffer size (samples)
        GyroBuffer;                                         % Buffer for gyro in-use calibration
        GyroMotionThreshold = 1.2;                          % Threshold for detecting motion

        GetADCFlag = 0;                                     % Flag for getdata/getadcdata

        LatestBatteryVoltageReading = 'Nan'; 
        GsrRange='Nan';                                     % Numerical value defining the gsr range of the Shimmer

        nClockOverflows = 0;                                % count number of clock overflows for time stamp calibration
        LastUncalibratedLoopTimeStamp = 0;                  % Last received uncalibrated looped time stamp data

    end

    properties
        name (1,:) {string};
        isConnected {logical} = false;
        isStreaming {logical} = false;

        % Vertices of a 3d representation of a shimmer object
        shimmer3d = struct('p1',[0.5,-1,0.2],'p2',[-0.5,-1,0.2],...
                       'p3',[-0.5,1,0.2],'p4',[0.5,1,0.2],...
                       'p5',[0.5,-1,-0.2],'p6',[-0.5,-1,-0.2],...
                       'p7',[-0.5,1,-0.2],'p8',[0.5,1,-0.2],...
                       'p9',[0.4,-0.9,0.3],'p10',[-0.4,-0.9,0.3],...
                       'p11',[-0.4,0.9,0.3],'p12',[0.4,0.9,0.3],...
                       'p13',[0.2,-1,0.05], 'p14',[0.2,-1,-0.05],...
                       'p15',[-0.2,-1,-0.05],'p16',[-0.2,-1,0.05]);
        shimmer3dRotated = struct('p1',[0,0,0,1],'p2',[0,0,0,1],...
                              'p3',[0,0,0,1],'p4',[0,0,0,1],...
                              'p5',[0,0,0,1],'p6',[0,0,0,1],...
                              'p7',[0,0,0,1],'p8',[0,0,0,1],...
                              'p9',[0,0,0,1],'p10',[0,0,0,1],...
                              'p11',[0,0,0,1],'p12',[0,0,0,1],...
                              'p13',[0,0,0,1], 'p14',[0,0,0,1],...
                              'p15',[0,0,0,1],'p16',[0,0,0,1]);
    end

    methods (Access = public)
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

                disp("Successfully connected to " + thisShimmer.name);
            catch
                disp("Failed to connect to " + thisShimmer.name);
            end

            if (readexgrate(thisShimmer, 2))
                disp("Read exg configuration from " + thisShimmer.name);
            end

            isConnected = thisShimmer.isConnected;
        end

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

            if (sensorsSet)
                readenabledsensors(thisShimmer);    % Following a succesful write, call the readenabledsensors function which updates the enabledSensors property with the current Shimmer enabled sensors setting                    
            end
        end

        function isSet = setaccelrange(thisShimmer, accelRange)
            %SETACCELRANGE - Set the accelerometer range of the Shimmer
            %
            %SETACCELRANGE(ACCELRANGE) sets the accelerometer range of the
            %   Shimmer to the value of the input ACCELRANGE.
            %   The function will return a 1 if the operation was successful
            %   otherwise it will return a 0.
            %
            %   SYNOPSIS: isSet = thisShimmer.setaccelrange(accelRange)
            %
            %   INPUT: accelRange - Numeric value defining the desired
            %                       accelerometer range.
            %                       Valid range setting values for the Shimmer
            %                       2 are 0 (+/- 1.5g), 1 (+/- 2g), 2 (+/- 4g)
            %                       and 3 (+/- 6g).
            %                       Valid range setting values for the Shimmer
            %                       2r are 0 (+/- 1.5g) and 3 (+/- 6g).
            %                       Valid range setting values for the
            %                       Shimmer3 with LSM303DLHC are 0 (+/- 2g),
            %                       1 (+/- 4g), 2 (+/- 8g) and 3 (+/- 16g).
            %                       Valid range setting values for the
            %                       Shimmer3 with LSM303AHTR are 0 (+/- 2g),
            %                       1 (+/- 16g), 2 (+/- 4g) and 3 (+/- 8g).
            %
            %   OUTPUT: isSet - Boolean value which indicates if the operation was
            %                   successful or not (1=TRUE, 0=FALSE).
            %
            %   EXAMPLE: isSet = shimmer1.setaccelrange(0);
            %
            %   See also getaccelrange
            
            if (thisShimmer.isConnected)                     % Shimmer must be in a Connected state
                
                isWritten = writeaccelrange(thisShimmer,accelRange);       % Write accelerometer range to the Shimmer
                
                if (isWritten)
                    isRead = readaccelrange(thisShimmer);                  % Following a succesful write, call the readaccelrange function which updates the accelRange property with the current Shimmer accel range setting
                    
                    if (isRead)
                        isSet = (accelRange == thisShimmer.AccelRange);    % isSet will be equal to 1 the current Accel range setting is equal to the requested setting
                        disp('Please ensure you are using the correct calibration parameters. Note that the Shimmer only stores one set (one range per sensor) of calibration parameters.');
                        thisShimmer.readconfigbytes;                   % update config bytes class properties
                        thisShimmer.DAccelCalParametersOV = thisShimmer.AccelWideRangeCalParametersOVShimmer3;
                        thisShimmer.DAccelCalParametersAM = thisShimmer.AccelWideRangeCalParametersAMShimmer3_2;
                        if (thisShimmer.getaccelrange==0 && thisShimmer.DefaultAccelCalibrationParameters == true)
                            thisShimmer.DAccelCalParametersSM = thisShimmer.AccelWideRangeCalParametersSM2gShimmer3_2;
                        end
                        if (thisShimmer.getaccelrange==1 && thisShimmer.DefaultDAccelCalibrationParameters == true)
                            thisShimmer.DAccelCalParametersSM = thisShimmer.AccelWideRangeCalParametersSM16gShimmer3_2;
                        end
                        if (thisShimmer.getaccelrange==2 && thisShimmer.DefaultDAccelCalibrationParameters == true)
                            thisShimmer.DAccelCalParametersSM = thisShimmer.AccelWideRangeCalParametersSM4gShimmer3_2;
                        end
                        if (thisShimmer.getaccelrange==3 && thisShimmer.DefaultDAccelCalibrationParameters == true)
                            thisShimmer.DAccelCalParametersSM = thisShimmer.AccelWideRangeCalParametersSM8gShimmer3_2;
                        end
                    else
                        isSet = false;
                    end
                    
                else
                    isSet = false;
                end
                
            else
                fprintf(strcat('Warning: setaccelrange - Cannot set accel range for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
                isSet = false;
            end
        end % function setaccelrange

        function samplingRate = setsamplingrate(thisShimmer, samplingRate)
            %SETSAMPLINGRATE - Sets the sampling rate of the Shimmer
            %
            %   SAMPLINGRATE = SETSAMPLINGRATE(SAMPLINGRATE) sets the
            %   sampling rate of the Shimmer to the closest available value to
            %   the input value SAMPLINGRATE. There are a limited number of
            %   sampling rates available, these are defined in the
            %   'Sampling Rate Table.txt'. The actual sampling rate setting
            %   after the operation is returned from the function.
            %
            %   SYNOPSIS: samplingRate = thisShimmer.setsamplingrate(samplingRate)
            %
            %   INPUT: samplingRate - Numeric value defining the desired
            %                         sampling rate in Hertz.
            %
            %   OUTPUT: samplingRate - Numeric value defining the actual sampling
            %                          rate setting (in Hertz) after the operation.
            %
            %   EXAMPLE: samplingRate = shimmer1.setsamplingrate(51.2);
            %
            %   See also getsamplingrate
            
            if (thisShimmer.isConnected)                     % Shimmer must be in a Connected state
                
                isWritten = writesamplingrate(thisShimmer, samplingRate);   % Write samplingRate value to the Shimmer
                
                if (isWritten)
                    isRead = readsamplingrate(thisShimmer);                % Following a succesful write, call the readsamplingrate function which updates the SamplingRate property with the current Shimmer sampling rate setting
                    if (isRead)
                        samplingRate = thisShimmer.SamplingRate;           % Following a successful write and successful read, set the return value (samplingRate) to value stored in the SamplingRate property
                        disp(['setsamplingrate - Shimmer Sampling Rate is set to ' num2str(samplingRate) 'Hz']);
                        
                        % set ExG rate as close as possible to Shimmer sampling rate; but never lower
                        if (thisShimmer.SamplingRate <= 125)
                            thisShimmer.setexgrate(0,1);               % set data rate to 125Hz for SENSOR_EXG1
                            thisShimmer.setexgrate(0,2);               % set data rate to 125Hz for SENSOR_EXG2
                            disp('setsamplingrate - ExG Rate is set to 125Hz');
                        elseif (thisShimmer.SamplingRate <= 250)
                            thisShimmer.setexgrate(1,1);               % set data rate to 250Hz for SENSOR_EXG1
                            thisShimmer.setexgrate(1,2);               % set data rate to 250Hz for SENSOR_EXG2
                            disp('setsamplingrate - ExG Rate is set to 250Hz');
                        elseif (thisShimmer.SamplingRate <= 500)
                            thisShimmer.setexgrate(2,1);               % set data rate to 500Hz for SENSOR_EXG1
                            thisShimmer.setexgrate(2,2);               % set data rate to 500Hz for SENSOR_EXG2
                            disp('setsamplingrate - ExG Rate is set to 500Hz');
                        elseif (thisShimmer.SamplingRate <= 1000)
                            thisShimmer.setexgrate(3,1);               % set data rate to 1000Hz for SENSOR_EXG1
                            thisShimmer.setexgrate(3,2);               % set data rate to 1000Hz for SENSOR_EXG2
                            disp('setsamplingrate - ExG Rate is set to 1000Hz');
                        elseif (thisShimmer.SamplingRate <= 2000)
                            thisShimmer.setexgrate(4,1);               % set data rate to 2000Hz for SENSOR_EXG1
                            thisShimmer.setexgrate(4,2);               % set data rate to 2000Hz for SENSOR_EXG2
                            disp('setsamplingrate - ExG Rate is set to 2000Hz');
                        elseif (thisShimmer.SamplingRate <= 4000)
                            thisShimmer.setexgrate(5,1);               % set data rate to 4000Hz for SENSOR_EXG1
                            thisShimmer.setexgrate(5,2);               % set data rate to 4000Hz for SENSOR_EXG2
                            disp('setsamplingrate - ExG Rate is set to 4000Hz');
                        elseif (thisShimmer.SamplingRate <= 32768)
                            thisShimmer.setexgrate(6,1);               % set data rate to 8000Hz for SENSOR_EXG1
                            thisShimmer.setexgrate(6,2);               % set data rate to 8000Hz for SENSOR_EXG2
                            disp('setsamplingrate - ExG Rate is set to 8000Hz');
                        end
                        
                        % set WR Accel data rate as close as possible to Shimmer sampling rate; but never lower
                        if (thisShimmer.SamplingRate <= 12.5)
                            thisShimmer.setaccelrate(1);                   % set data rate to 12.5Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 12.5Hz');
                        elseif (thisShimmer.SamplingRate <= 25)
                            thisShimmer.setaccelrate(2);                   % set data rate to 25Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 25Hz');
                        elseif (thisShimmer.SamplingRate <= 50)
                            thisShimmer.setaccelrate(3);                   % set data rate to 50Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 50Hz');
                        elseif (thisShimmer.SamplingRate <= 100)
                            thisShimmer.setaccelrate(4);                   % set data rate to 100Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 100Hz');
                        elseif (thisShimmer.SamplingRate <= 200)
                            thisShimmer.setaccelrate(5);                   % set data rate to 200Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 200Hz');
                        elseif (thisShimmer.SamplingRate <= 400)
                            thisShimmer.setaccelrate(6);                   % set data rate to 400Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 400Hz');
                        elseif (thisShimmer.SamplingRate <= 800)
                            thisShimmer.setaccelrate(7);                   % set data rate to 800Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 800Hz');
                        elseif (thisShimmer.SamplingRate <= 1600)
                            thisShimmer.setaccelrate(8);                   % set data rate to 1600Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 1600Hz');
                        elseif (thisShimmer.SamplingRate <= 3200)
                            thisShimmer.setaccelrate(9);                   % set data rate to 3200Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 3200Hz');
                        elseif (thisShimmer.SamplingRate <= 32768)
                            thisShimmer.setaccelrate(10);                  % set data rate to 6400Hz for WR accel
                            disp('setsamplingrate - WR Accel Rate is set to 6400Hz');
                        end
                        
                        % set Gyro data rate as close as possible to Shimmer sampling rate; but never lower
                        if (thisShimmer.SamplingRate <= 32768)
                            gyroRate = min(255, floor(8000/thisShimmer.SamplingRate - 1));                      % gyro rate to send to Shimmer -> programmable from 4..8000Hz)
                            if (gyroRate>=0)
                                thisShimmer.setgyrorate(gyroRate);
                                actualRate = 8000/(1+gyroRate);                                                 % actual gyro rate
                            else
                                thisShimmer.setgyrorate(0);
                                actualRate = 8000;
                            end
                            fprintf(['setsamplingrate - Gyro Rate is set to' ' ' num2str(actualRate) 'Hz.\n']);
                        end
                                                
                        % set Mag data rate as close as possible to Shimmer sampling rate; but never lower
                        if (thisShimmer.SamplingRate <= 10.0)
                            thisShimmer.setmagrate(0);                     % set data rate to 10.0Hz for Mag
                            disp('setsamplingrate - Mag Rate is set to 10.0Hz');
                        elseif (thisShimmer.SamplingRate <= 20.0)
                            thisShimmer.setmagrate(1);                     % set data rate to 20.0Hz for Mag
                            disp('setsamplingrate - Mag Rate is set to 20.0Hz');
                        elseif (thisShimmer.SamplingRate <= 50.0)
                            thisShimmer.setmagrate(2);                     % set data rate to 50.0Hz for Mag
                            disp('setsamplingrate - Mag Rate is set to 50.0Hz');
                        elseif (thisShimmer.SamplingRate <= 32768)
                            thisShimmer.setmagrate(3);                     % set data rate to 100.0Hz for Mag
                            disp('setsamplingrate - Mag Rate is set to 100.0Hz');
                        end
                    else
                        samplingRate = 'Nan';                              % Following a successful write but failed read, set the return value (samplingRate) to 'Nan' signifying unknown
                    end
                else
                    samplingRate = thisShimmer.SamplingRate;               % Following a failed write, set the return value (samplingRate) to value stored in the SamplingRate property
                end
            else
                fprintf(strcat('Warning: setsamplingrate - Cannot set sampling range for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
                samplingRate = 'Nan';
            end
            
        end % function setsamplingrate
    end
    
    methods (Access = private)
        function isRead = readenabledsensors(thisShimmer)
            % Calls the inquiry function and updates the EnabledSensors property.
            if (thisShimmer.isConnected)
                
                flush(thisShimmer.bluetoothConn, "input");                          % As a precaution always clear the read data buffer before a write
                isRead = inquiry(thisShimmer);                             % Send an inquiry command to the Shimmer
                                                
                if (~isRead)
                    thisShimmer.EnabledSensors = 'Nan';                    % Set the EnabledSensors to 'Nan' to indicate unknown
                    fprintf(strcat('Warning: readenabledsensors - inquiry command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    isRead = false;
                end
                
            else
                isRead = false;
                fprintf(strcat('Warning: readenabledsensors - Cannot get enabled sensors for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
            
        end % function readenabledsensors

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
                fprintf(strcat('Warning: waitForAck - Timed-out on wait for acknowledgement byte on Shimmer COM',thisShimmer.name,'.\n'));
            end
            
        end %function waitForAck

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

        function isRead = readaccelrange(thisShimmer)
            % Sends the GET_ACCEL_RANGE_COMMAND to Shimmer - in Connected state 
            % Receives the accel range and updates the AccelRange property.
            if (thisShimmer.isConnected)
                
                flush(thisShimmer.bluetoothConn, "input");                                          % As a precaution always clear the read data buffer before a write
                write(thisShimmer.bluetoothConn, thisShimmer.GET_ACCEL_RANGE_COMMAND);          % Send the Set Accel Range Command to the Shimmer
                
                isAcknowledged = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);     % Wait for Acknowledgment from Shimmer
                
                if (isAcknowledged == true)
                    [shimmerResponse] = read(thisShimmer.bluetoothConn, 2);        % Read the 2 byte response from the bluetooth buffer
                    
                    if ~isempty(shimmerResponse)
                        
                        if (shimmerResponse(1) == thisShimmer.ACCEL_RANGE_RESPONSE)
                            thisShimmer.AccelRange = shimmerResponse(2);
                            isRead = true;
                        else
                            thisShimmer.AccelRange = 'Nan';                % Set the AccelRange to 'Nan' to indicate unknown
                            fprintf(strcat('Warning: readaccelrange - Get accel range command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                            isRead = false;
                        end
                    else
                        thisShimmer.AccelRange = 'Nan';                % Set the AccelRange to 'Nan' to indicate unknown
                        fprintf(strcat('Warning: readaccelrange - Get accel range command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                        isRead = false;
                    end
                else
                    thisShimmer.AccelRange = 'Nan';                        % Set the AccelRange to 'Nan' to indicate unknown
                    fprintf(strcat('Warning: readaccelrange - Get accel range command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    isRead = false;
                end
                
            else
                isRead = false;
                fprintf(strcat('Warning: readaccelrange - Cannot get accel range for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
            
        end % function readaccelrange

        function isWritten = writeaccelrange(thisShimmer,accelRange)
            % Writes accelerometer range to Shimmer - in Connected state
            % This function is for Shimmer2, Shimmer2r and Shimmer3. For
            % Shimmer3 this function writes the range for the
            % LSM303DLHC/LSM303AHTR accelerometer.
            if (thisShimmer.isConnected)
                if ((accelRange == 0) || (accelRange == 1)|| (accelRange == 2)|| (accelRange == 3))
                    validSetting = true;
                else 
                    validSetting = false;
                end
                
                if (validSetting == true)
                    
                    flush(thisShimmer.bluetoothConn, "input");                                  % As a precaution always clear the read data buffer before a write
                    write(thisShimmer.bluetoothConn, thisShimmer.SET_ACCEL_RANGE_COMMAND);      % Send the Set accel range Command to the Shimmer
                    waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);
                    
                    write(thisShimmer.bluetoothConn, char(accelRange));                         % Write the accel range char value to the Shimmer
                    isWritten = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);           % Wait for Acknowledgment from Shimmer
                    
                    if (~isWritten)
                        fprintf(strcat('Warning: writeaccelrange - Set accel range response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    end
                else
                    isWritten = false;
                    fprintf(strcat('Warning: writeaccelrange - Attempt to set accel range failed due to a request to set the range to an \n'));
                    fprintf(strcat('invalid setting for Shimmer COM',thisShimmer.name,'.\n'));
                    fprintf('Valid range setting values for the Shimmer 3 are 0 (+/- 2g), 1 (+/- 4g), 2 (+/- 8g) and 3 (+/- 16g).\n');
                end
                
            else
                isWritten = false;
                fprintf(strcat('Warning: writeaccelrange - Cannot set accel range for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
            
        end % function writeaccelrange

        function isSet = setexgrate(thisShimmer, exgRate, chipIdentifier) % function setexgrate  
            %SETEXGRATE - Set the exg rate on the Shimmer
            %
            %   SETEXGRATE(EXGRATE, CHIPIDENTIFIER) sets the ExG Data Rate
            %   for chip CHIPIDENTIER on the Shimmer to the value of the
            %   input EXGRATE. The function will return a 1 if the
            %   operation was successful otherwise it will return a 0.
            %
            %   SYNOPSIS: isSet = thisShimmer.setexgrate(exgRate, chipIdentifier)
            %
            %   INPUT: exgRate -  Numeric value defining the desired exg
            %                     data rate. Valid rate settings are 0
            %                     (125 Hz), 1 (250 Hz), 2 (500 Hz
            %                     (default)), 3 (1000 Hz), 4 (2000 Hz), 5
            %                     (4000 Hz), 6 (8000 Hz)
            % 
            %   INPUT: chipIdentifier - numeric value to select SENSOR_EXG1 or SENSOR_EXG2
            %
            %   OUTPUT: isSet -   Boolean value which indicates if the
            %                     operation was successful or not (1=TRUE, 0=FALSE).
            %
            %   EXAMPLE: isSet = shimmer1.setexgrate(4,2);
            %
            %   See also getexgrate
            if (thisShimmer.isConnected)                     % Shimmer must be in a Connected state
                
                isWritten = writeexgrate(thisShimmer, exgRate, chipIdentifier); % Write exgRate to the Shimmer
                
                if (isWritten)
                    isRead = readexgrate(thisShimmer, chipIdentifier);          % Following a succesful write, call the readexgrate function which updates the exgRate property with the current Shimmer exg rate setting
                    
                    if (isRead)
                        if (chipIdentifier == 1)
                            isSet = (exgRate == thisShimmer.EXG1Rate);          % isSet will be equal to 1 the current exg rate setting is equal to the requested setting
                        else
                            isSet = (exgRate == thisShimmer.EXG2Rate);
                        end
                    else
                        isSet = false;
                    end
                else
                    isSet = false;
                end
            else
                fprintf(strcat('Warning: setexgrate - Cannot set exg rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
                isSet = false;
            end
        end % function setexgrate

        function isRead = readexgconfiguration(thisShimmer,chipIdentifier)  % chipIdentifier selects SENSOR_EXG1 or SENSOR_EXG2
            % Sends the GET_EXG_REGS_COMMAND to Shimmer3 - in Connected state 
            % Receives (all) ExG configuration bytes and updates the corresponding properties. 
            if (thisShimmer.isConnected && (chipIdentifier == 1 || chipIdentifier == 2))
                
                flush(thisShimmer.bluetoothConn, "input");                                          % As a precaution always clear the read data buffer before a write
                write(thisShimmer.bluetoothConn, thisShimmer.GET_EXG_REGS_COMMAND);
                write(thisShimmer.bluetoothConn, char(chipIdentifier-1));                       % char(0) selects SENSOR_EXG1, char(1) selects SENSOR_EXG2
                write(thisShimmer.bluetoothConn, char(0));
                write(thisShimmer.bluetoothConn, char(10));
                isAcknowledged = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);     % Wait for acknowledgment from Shimmer
                
                if (isAcknowledged == true)
                    serialData = [];
                    nIterations = 0;
                    while(length(serialData) < 12 && nIterations < 4 )                                       % Read the 12 byte response from the realterm buffer
                        [tempSerialData] = read(thisShimmer.bluetoothConn, inf);   % Read all available serial data from the com port
                        serialData = [serialData; tempSerialData];
                        pause(.2);
                        nIterations = nIterations + 1;
                    end
                    shimmerResponse = serialData(1:12);
                    ExG1Failed = false;
                    ExG2Failed = false;
                    if ~isempty(shimmerResponse)
                        if (chipIdentifier==1)
                            if (shimmerResponse(1) == thisShimmer.EXG_REGS_RESPONSE)
                                thisShimmer.EXG1Config1 = shimmerResponse(3);
                                thisShimmer.EXG1Config2 = shimmerResponse(4);
                                thisShimmer.EXG1Loff = shimmerResponse(5);
                                thisShimmer.EXG1Ch1Set = shimmerResponse(6);
                                thisShimmer.EXG1Ch2Set = shimmerResponse(7);
                                thisShimmer.EXG1RLD_Sens = shimmerResponse(8);
                                thisShimmer.EXG1LOFF_Sens = shimmerResponse(9);
                                thisShimmer.EXG1LOFF_Stat = shimmerResponse(10);
                                thisShimmer.EXG1Resp1 = shimmerResponse(11);
                                thisShimmer.EXG1Resp2 = shimmerResponse(12);
                                thisShimmer.EXG1CH1Gain = convertEXGGain(thisShimmer, bitshift(bitand(112,thisShimmer.EXG1Ch1Set),-4));
                                thisShimmer.EXG1CH2Gain = convertEXGGain(thisShimmer, bitshift(bitand(112,thisShimmer.EXG1Ch2Set),-4));
                                thisShimmer.EXG1Rate = bitand(thisShimmer.EXG1Config1,7);
                                isRead = true;
                            else
                                ExG1Failed = true;
                            end
                        elseif (chipIdentifier==2)
                            if (shimmerResponse(1) == thisShimmer.EXG_REGS_RESPONSE)
                                thisShimmer.EXG2Config1 = shimmerResponse(3);
                                thisShimmer.EXG2Config2 = shimmerResponse(4);
                                thisShimmer.EXG2Loff = shimmerResponse(5);
                                thisShimmer.EXG2Ch1Set = shimmerResponse(6);
                                thisShimmer.EXG2Ch2Set = shimmerResponse(7);
                                thisShimmer.EXG2RLD_Sens = shimmerResponse(8);
                                thisShimmer.EXG2LOFF_Sens = shimmerResponse(9);
                                thisShimmer.EXG2LOFF_Stat = shimmerResponse(10);
                                thisShimmer.EXG2Resp1 = shimmerResponse(11);
                                thisShimmer.EXG2Resp2 = shimmerResponse(12);
                                thisShimmer.EXG2CH1Gain = convertEXGGain(thisShimmer, bitshift(bitand(112,thisShimmer.EXG2Ch1Set),-4));
                                thisShimmer.EXG2CH2Gain = convertEXGGain(thisShimmer, bitshift(bitand(112,thisShimmer.EXG2Ch2Set),-4));
                                thisShimmer.EXG2Rate = bitand(thisShimmer.EXG2Config1,7);
                                isRead = true;
                            else
                                ExG2Failed = true;
                            end
                        end
                    else
                        if (chipIdentifier == 1)
                            ExG1Failed = true;
                        elseif (chipIdentifier == 2)
                            ExG2Failed = true;
                        end
                    end
                else
                    if (chipIdentifier == 1)
                        ExG1Failed = true;
                    elseif (chipIdentifier == 2)
                        ExG2Failed = true;
                    end
                    fprintf(strcat('Warning: readexgconfiguration - Get EXG settings command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    isRead = false;
                end
                if(ExG1Failed == true)
                    thisShimmer.EXG1Config1 = 'Nan';
                    thisShimmer.EXG1Config2 = 'Nan';
                    thisShimmer.EXG1Loff = 'Nan';
                    thisShimmer.EXG1Ch1Set = 'Nan';
                    thisShimmer.EXG1Ch2Set = 'Nan';
                    thisShimmer.EXG1RLD_Sens = 'Nan';
                    thisShimmer.EXG1LOFF_Sens = 'Nan';
                    thisShimmer.EXG1LOFF_Stat = 'Nan';
                    thisShimmer.EXG1Resp1 = 'Nan';
                    thisShimmer.EXG1Resp2 = 'Nan';
                    thisShimmer.EXG1CH1Gain = 'Nan';
                    thisShimmer.EXG1CH2Gain = 'Nan';
                    thisShimmer.EXG1Rate = 'Nan';
                    fprintf(strcat('Warning: readexgconfiguration - Get EXG settings command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    isRead = false;
                end
                if(ExG2Failed == true)
                    thisShimmer.EXG2Config1 = 'Nan';
                    thisShimmer.EXG2Config2 = 'Nan';
                    thisShimmer.EXG2Loff = 'Nan';
                    thisShimmer.EXG2Ch1Set = 'Nan';
                    thisShimmer.EXG2Ch2Set = 'Nan';
                    thisShimmer.EXG2RLD_Sens = 'Nan';
                    thisShimmer.EXG2LOFF_Sens = 'Nan';
                    thisShimmer.EXG2LOFF_Stat = 'Nan';
                    thisShimmer.EXG2Resp1 = 'Nan';
                    thisShimmer.EXG2Resp2 = 'Nan';
                    thisShimmer.EXG2CH1Gain = 'Nan';
                    thisShimmer.EXG2CH2Gain = 'Nan';
                    thisShimmer.EXG2Rate = 'Nan';
                    fprintf(strcat('Warning: readexgconfiguration - Get EXG settings command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    isRead = false;
                end
            elseif(~(chipIdentifier == 1 || chipIdentifier == 2))
                isRead = false;
                disp('Warning: readexgconfiguration - Invalid chip identifier (please use 1 (Chip1) or 2 (Chip2).');
            else
                isRead = false;
                fprintf(strcat('Warning: readexgconfiguration - Cannot get EXG settings for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
            
        end % function readEXGconfiguration

        function isWritten = writesamplingrate(thisShimmer,samplingRate)
            % Writes sampling rate to Shimmer - in Connected state.
            if (thisShimmer.isConnected)
                
                flush(thisShimmer.bluetoothConn, "input");                                 % As a precaution always clear the read data buffer before a write
                write(thisShimmer.bluetoothConn, thisShimmer.SET_SAMPLING_RATE_COMMAND);  % Send the Set Sampling Rate Command to the Shimmer
                samplingByteValue = uint16(32768/samplingRate);
                write(thisShimmer.bluetoothConn, char(bitand(255,samplingByteValue)));
                write(thisShimmer.bluetoothConn, char(bitshift(samplingByteValue,-8)));

                isWritten = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);   % Wait for Acknowledgment from Shimmer

                if (isWritten == false)
                    fprintf(strcat('Warning: writesamplingrate - Set sampling rate command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                end
                
            else
                isWritten = false;
                fprintf(strcat('Warning: writesamplingrate - Cannot set sampling rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
            
        end % function writesamplingrate

        function isRead = readsamplingrate(thisShimmer)
            % Sends the GET_SAMPLING_RATE_COMMAND to Shimmer - in Connected state 
            % Receives the sampling rate and updates the SamplingRate property.
            if (thisShimmer.isConnected)
                
                flush(thisShimmer.bluetoothConn, "input");                                       % As a precaution always clear the read data buffer before a write
                write(thisShimmer.bluetoothConn, thisShimmer.GET_SAMPLING_RATE_COMMAND);     % Send the Get Sampling Rate Command to the Shimmer
                
                isAcknowledged = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);  % Wait for Acknowledgment from Shimmer
                
                if (isAcknowledged == true)
                    [shimmerResponse] = read(thisShimmer.bluetoothConn, thisShimmer.bluetoothConn.NumBytesAvailable);     % Read the 2 byte response from the realterm buffer
                    
                    if ~isempty(shimmerResponse)
                        
                        if (shimmerResponse(1) == thisShimmer.SAMPLING_RATE_RESPONSE)
                            if shimmerResponse(2) == 255                                % samplingRate == 0 is a special case, refer to 'Sampling Rate Table.txt' for more details
                                thisShimmer.SamplingRate = 0;
                            else
                                thisShimmer.SamplingRate = 1024 / double(shimmerResponse(2));   % Refer to 'Sampling Rate Table.txt' for more details
                            end
                            isRead = true;
                        else
                            thisShimmer.SamplingRate = 'Nan';              % Set the SamplingRate to 'Nan' to indicate unknown
                            fprintf(strcat('Warning: readsamplingrate - Get sampling rate command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                            isRead = false;
                        end
                    else
                        thisShimmer.SamplingRate = 'Nan';              % Set the SamplingRate to 'Nan' to indicate unknown
                        fprintf(strcat('Warning: readsamplingrate - Get sampling rate command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                        isRead = false;
                    end
                else
                    thisShimmer.SamplingRate = 'Nan';                      % Set the SamplingRate to 'Nan' to indicate unknown
                    fprintf(strcat('Warning: readsamplingrate - Get sampling rate command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    isRead = false;
                end
                
            else
                isRead = false;
                fprintf(strcat('Warning: readsamplingrate - Cannot get sampling rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
            
        end % function readsamplingrate

        function isRead = readconfigbytes(thisShimmer)     
            % Sends the GET_CONFIG_BYTE0_COMMAND to Shimmer3 - in Connected state 
            % Receives Config Byte 0, Config Byte 1, Config Byte 2 and Config Byte 3
            % and updates the corresponding properties.
            if (thisShimmer.isConnected)
                flush(thisShimmer.bluetoothConn, "input");                                           % As a precaution always clear the read data buffer before a write                
                write(thisShimmer.bluetoothConn, thisShimmer.GET_CONFIG_BYTE0_COMMAND);          % Send GET_CONFIG_BYTE0_COMMAND to Shimmer3 to get config bytes byte0, byte1, byte2, byte3.              
                isAcknowledged = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);      % Wait for Acknowledgment from Shimmer                
                if (isAcknowledged == true)
                    [shimmerResponse] = read(thisShimmer.bluetoothConn, 5);     % Read the 5 byte response from the bluetooth buffer  
                    if ~isempty(shimmerResponse)
                        if (shimmerResponse(1) == thisShimmer.CONFIG_BYTE0_RESPONSE)
                            thisShimmer.ConfigByte0 = shimmerResponse(2);
                            thisShimmer.ConfigByte1 = shimmerResponse(3);
                            thisShimmer.ConfigByte2 = shimmerResponse(4);
                            thisShimmer.ConfigByte3 = shimmerResponse(5);
                            isRead = true;
                        else
                            thisShimmer.ConfigByte0 = 'Nan';                                % Set the ConfigByte0 to 'Nan' to indicate unknown
                            thisShimmer.ConfigByte1 = 'Nan';                                % Set the ConfigByte1 to 'Nan' to indicate unknown
                            thisShimmer.ConfigByte2 = 'Nan';                                % Set the ConfigByte2 to 'Nan' to indicate unknown
                            thisShimmer.ConfigByte3 = 'Nan';                                % Set the ConfigByte3 to 'Nan' to indicate unknown
                            fprintf(strcat('Warning: readconfigbytes - Get config byte0 command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                            isRead = false;
                        end
                    else
                        thisShimmer.ConfigByte0 = 'Nan';                                    % Set the ConfigByte0 to 'Nan' to indicate unknown
                        thisShimmer.ConfigByte1 = 'Nan';                                    % Set the ConfigByte1 to 'Nan' to indicate unknown
                        thisShimmer.ConfigByte2 = 'Nan';                                    % Set the ConfigByte2 to 'Nan' to indicate unknown
                        thisShimmer.ConfigByte3 = 'Nan';                                    % Set the ConfigByte3 to 'Nan' to indicate unknown
                        fprintf(strcat('Warning: readconfigbytes - Get config byte0 command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                        isRead = false;
                    end
                else
                    thisShimmer.ConfigByte0 = 'Nan';                                        % Set the ConfigByte0 to 'Nan' to indicate unknown                        
                    thisShimmer.ConfigByte1 = 'Nan';                                        % Set the ConfigByte1 to 'Nan' to indicate unknown
                    thisShimmer.ConfigByte2 = 'Nan';                                        % Set the ConfigByte2 to 'Nan' to indicate unknown
                    thisShimmer.ConfigByte3 = 'Nan';                                        % Set the ConfigByte3 to 'Nan' to indicate unknown
                    fprintf(strcat('Warning: readconfigbytes - Get config byte0 command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    isRead = false;
                end
            else
                isRead = false;
                fprintf(strcat('Warning: readconfigbytes - Cannot get config byte0 for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
        end % function readconfigbytes

        function accelRange = getaccelrange(thisShimmer)
            %GETACCELRANGE - Get the accelerometer range of the Shimmer
            %
            %   ACCELRANGE = GETACCELRANGE returns the accelerometer
            %   range setting of the Shimmer.
            %
            %   SYNOPSIS: accelRange = thisShimmer.getaccelrange()
            %
            %   OUTPUT: accelRange - Numeric value defining the accelerometer
            %                        range.
            %                        Valid range setting values for the Shimmer
            %                        2 are 0 (+/- 1.5g), 1 (+/- 2g), 2 (+/- 4g)
            %                        and 3 (+/- 6g).
            %                        Valid range setting values for the Shimmer
            %                        2r are 0 (+/- 1.5g) and 3 (+/- 6g).
            %
            %   EXAMPLE: accelRange = shimmer1.getaccelrange;
            %
            %   See also setaccelrange
            
            if (thisShimmer.isConnected)                     % Shimmer must be in a Connected state
                accelRange = thisShimmer.AccelRange;
            else
                accelRange = 'Nan';
                fprintf(strcat('Warning: getaccelrange - Cannot determine accelerometer range as COM ',thisShimmer.name,' Shimmer is not Connected.\n'));
            end
        end

        function isSet = setmagrate(thisShimmer, magRate)
            %SETMAGRATE - Set the Mag Data Rate on the Shimmer
            %
            %   SETMAGRATE(MAGRATE) sets the mag data rate on the Shimmer 
            %   to the value of the input MAGRATE.
            %   The function will return a 1 if the operation was successful
            %   otherwise it will return a 0.
            %
            %   SYNOPSIS: isSet = thisShimmer.setmagrate(magRate)
            %
            %   INPUT: magRate - Numeric value defining the desired mag
            %                    data rate. Valid rate settings for Shimmer 2 are 0 (0.5
            %                    Hz), 1 (1.0 Hz), 2 (2.0 Hz), 3 (5.0 Hz), 4
            %                    (10.0 Hz), 5 (20.0 Hz), 6 (50.0 Hz). For
            %                    Shimmer3 with LSM303DLHC valid settings are
            %                    0 (0.75Hz), 1 (1.5Hz), 2 (3Hz), 3 (7.5Hz),
            %                    4 (15Hz), 5 (30Hz), 6 (75Hz), 7 (220Hz). For 
            %                    Shimmer3 with LSM303AHTR valid settings are
            %                    0 (10.0Hz), 1 (20.0Hz)), 2 (50.0Hz), 3 (100.0Hz).
            %
            %   OUTPUT: isSet - Boolean value which indicates if the operation was
            %                   successful or not (1=TRUE, 0=FALSE).
            %
            %   EXAMPLE: isSet = shimmer1.setmagrate(1);
            %
            %   
            
            if (thisShimmer.isConnected)                     % Shimmer must be in a Connected state
                
                isWritten = writemagrate(thisShimmer,magRate);             % Write mag range to the Shimmer
                
                if (isWritten)
                    isRead = readmagrate(thisShimmer);                     % Following a succesful write, call the readmagrange function which updates the magRange property with the current Shimmer mag range setting
                    
                    if (isRead)
                        thisShimmer.readconfigbytes;                       % update config bytes class properties
                        isSet = (magRate == thisShimmer.MagRate);          % isSet will be equal to 1 the current mag range setting is equal to the requested setting
                    else
                        isSet = false;
                    end
                else
                    isSet = false;
                end
                
            else
                fprintf(strcat('Warning: setmagrate - Cannot set mag rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
                isSet = false;
            end
        end % function setmagrate
              
        function isSet = setaccelrate(thisShimmer, accelRate)
            %SETACCELRATE - Set the Wide Range Accel (Digital Accel) Data Rate on the Shimmer3
            %
            %   SETACCELRATE(ACCELRATE) sets the mag data rate on the Shimmer 
            %   to the value of the input ACCELRATE.
            %   The function will return a 1 if the operation was successful
            %   otherwise it will return a 0.
            %
            %   SYNOPSIS: isSet = thisShimmer.setaccelrate(accelRate)
            %
            %   INPUT: accelRate - Numeric value defining the desired accel
            %                    data rate. Valid rate settings for Shimmer3 
            %                    with LSM303DLHC are 1 (1.0 Hz), 2 (10.0 Hz), 3 (25.0 Hz), 4
            %                    (50.0 Hz), 5 (100.0 Hz), 6 (200.0 Hz), 7 (400.0 Hz) and 9 (1344.0Hz).
            %                    Valid rate settings for Shimmer3 with LSM303AHTR are
            %                    1 (12.5 Hz), 2 (25.0 Hz), 3 (50.0 Hz), 4 (100.0 Hz), 
            %                    5 (200.0 Hz), 6 (400.0 Hz), 7 (800.0 Hz), 8 (1600.0 Hz), 
            %                    9 (3200.0Hz) and 10 (6400.0Hz).  
            %
            %   OUTPUT: isSet - Boolean value which indicates if the operation was
            %                   successful or not (1=TRUE, 0=FALSE).
            %
            %   EXAMPLE: isSet = shimmer1.setaccelrate(1);
            %

            if (thisShimmer.isConnected)                                  % Shimmer must be in a Connected state
                isWritten = writeaccelrate(thisShimmer,accelRate);                  % Write mag range to the Shimmer
                
                if (isWritten)
                    isRead = readaccelrate(thisShimmer);                            % Following a succesful write, call the readmagrange function which updates the magRange property with the current Shimmer mag range setting
                    
                    if (isRead)
                        thisShimmer.readconfigbytes;                                % update config bytes class properties
                        isSet = (accelRate == thisShimmer.AccelWideRangeDataRate);  % isSet will be equal to 1 the current mag range setting is equal to the requested setting
                    else
                        isSet = false;
                    end
                else
                    isSet = false;
                end
            else
                fprintf(strcat('Warning: setaccelrate - Cannot set accel rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
                isSet = false;
            end
        end % function setaccelrate
        
        function isSet = setgyrorate(thisShimmer, gyroRate)
            %SETGYRORATE - Set the Gyroscope Rate (MPU 9150) on the Shimmer3
            %
            %   SETGYRORATE(GYRORATE) sets the mag data rate on the Shimmer 
            %   to the value of the input GYRORATE.
            %   The function will return a 1 if the operation was successful
            %   otherwise it will return a 0.
            %
            %   SYNOPSIS: isSet = thisShimmer.setmagrate(magRate)
            %
            %   INPUT: gyroRate - Numeric value defining the desired mag
            %                    data rate. Valid rate settings for Shimmer
            %                    3 are 255 (31.25 Hz), 155(51.28 Hz), 45
            %                    (173.91 Hz), 30 (258.06 Hz), 14 (533.33 Hz), 6 (1142.86 Hz). 
            %   OUTPUT: isSet - Boolean value which indicates if the operation was
            %                   successful or not (1=TRUE, 0=FALSE).
            %
            %   EXAMPLE: isSet = shimmer1.setgyrorate(255);
            %
            
            if (thisShimmer.isConnected)                     % Shimmer must be in a Connected state
                isWritten = writegyrorate(thisShimmer,gyroRate);       % Write mag range to the Shimmer
                
                if (isWritten)
                    isRead = readgyrorate(thisShimmer);                % Following a succesful write, call the readmagrange function which updates the magRange property with the current Shimmer mag range setting
                    
                    if (isRead)
                        thisShimmer.readconfigbytes;                   % update config bytes class properties
                        isSet = (gyroRate == thisShimmer.GyroRate);    % isSet will be equal to 1 the current mag range setting is equal to the requested setting
                    else
                        isSet = false;
                    end
                else
                    isSet = false;
                end
            else
                fprintf(strcat('Warning: setgyrorate - Cannot set gyro rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
                isSet = false;
            end
        end % function setgyrorate

        function isWritten = writemagrate(thisShimmer,magRate)
            % Writes Magnetometer data rate to Shimmer2r or Shimmer3 - in Connected state
            if (thisShimmer.isConnected)
                
                if ((magRate == 0) || (magRate == 1) || (magRate == 2) || (magRate == 3))
                    
                    flush(thisShimmer.bluetoothConn, "input");                                    % As a precaution always clear the read data buffer before a write
                    write(thisShimmer.bluetoothConn, thisShimmer.SET_MAG_SAMPLING_RATE_COMMAND); % Send the Set Mag Rate Command to the Shimmer
                    
                    write(thisShimmer.bluetoothConn, char(magRate));                             % Write the mag rate char value to the Shimmer
                    isWritten = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);       % Wait for Acknowledgment from Shimmer
                    
                    if (isWritten == false)
                        fprintf(strcat('Warning: writemagrate - Set mag rate response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    end
                else
                    isWritten = false;
                    fprintf(strcat('Warning: writemagrate - Attempt to set mag rate failed due to a request to set the range to an \n'));
                    fprintf(strcat('invalid setting for Shimmer COM',thisShimmer.name,'.\n'));
                    fprintf('For Shimmer2r: Valid rate settings are 0 (0.5 Hz), 1 (1.0 Hz), 2 (2.0 Hz), 3 (5.0 Hz), 4 (10.0 Hz), 5 (20.0 Hz) and 6 (50.0 Hz).\n');
                    fprintf('For Shimmer3 with LSM303DLHC: Valid rate settings are 0 (0.75Hz), 1 (1.5Hz), 2 (3Hz), 3 (7.5Hz), 4 (15Hz), 5 (30Hz), 6 (75Hz), 7 (220Hz).\n');
                    fprintf('For Shimmer3 with LSM303AHTR: Valid rate settings are 0 (10.0Hz), 1 (20.0Hz)), 2 (50.0Hz), 3 (100.0Hz).\n');
                end
                
            else
                isWritten = false;
                fprintf(strcat('Warning: writemagrate - Cannot set mag rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
            
        end % function writemagrate      
        
        function isWritten = writeaccelrate(thisShimmer,accelRate)
            % Writes LSM303DLHC/LSM303AHTR accelerometer data rate for Shimmer3 - in Connected state
            if (thisShimmer.isConnected)
                if ((accelRate == 1) || (accelRate == 2) || (accelRate == 3) || (accelRate == 4) || (accelRate == 5)...
                        || (accelRate == 6) || (accelRate == 7) || (accelRate == 8) || (accelRate == 9) || (accelRate == 10))
                                           
                    flush(thisShimmer.bluetoothConn, "input");                                            % As a precaution always clear the read data buffer before a write
                    write(thisShimmer.bluetoothConn, thisShimmer.SET_LSM303DLHC_ACCEL_SAMPLING_RATE_COMMAND);  % Send the Set Mag Rate Command to the Shimmer
                    
                    write(thisShimmer.bluetoothConn, char(accelRate));                                         % Write the mag rate char value to the Shimmer
                    isWritten = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);                     % Wait for Acknowledgment from Shimmer
                    
                    if (isWritten == false)
                        fprintf(strcat('Warning: writeaccelrate - Set acc rate response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    end
                else
                    isWritten = false;
                    fprintf(strcat('Warning: writeaccelrate - Attempt to set acc rate failed due to a request to set the range to an \n'));
                    fprintf(strcat('invalid setting for Shimmer COM',thisShimmer.name,'.\n'));
                    fprintf(strcat('Valid rate settings are  1 (12.5 Hz), 2 (25.0 Hz), 3 (50.0 Hz), 4 (100.0 Hz), 5 (200.0 Hz), 6 (400.0 Hz), 7 (800.0 Hz), 8 (1600.0 Hz), 9 (3200.0Hz) and 10 (6400.0Hz).\n'));
                end
                
            else
                isWritten = false;
                fprintf(strcat('Warning: writeaccelrate - Cannot set accel rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
            
        end % function writeaccelrate
        
        function isWritten = writegyrorate(thisShimmer,gyroRate)
            % Writes MPU9150 gyroscope data rate for Shimmer3 - in Connected state
            if (thisShimmer.isConnected)
                
                if (gyroRate>=0 && gyroRate<=255)
                    
                    flush(thisShimmer.bluetoothConn, "input");                                        % As a precaution always clear the read data buffer before a write
                    write(thisShimmer.bluetoothConn, thisShimmer.SET_MPU9150_SAMPLING_RATE_COMMAND); % Send the Set Gyro Rate Command to the Shimmer
                    
                    write(thisShimmer.bluetoothConn, char(gyroRate));                                % Write the gyroRate char value to the Shimmer
                    isWritten = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);           % Wait for acknowledgment from Shimmer
                    
                    if (isWritten == false)
                        fprintf(strcat('Warning: writegyrorate - Set gyro rate response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    end
                else
                    isWritten = false;
                    fprintf(strcat('Warning: writegyrorate - Attempt to set gyro rate failed due to a request to set the range to an \n'));
                    fprintf(strcat('invalid setting for Shimmer COM',thisShimmer.name,'.\n'));
                    fprintf(strcat('Valid range settings are 0 - 255, see datasheet of MPU9150 for further info'));
                end
                
            else
                isWritten = false;
                fprintf(strcat('Warning: writegyrorate - Cannot set gyro rate for COM ',thisShimmer.name,' as Shimmer is not connected\n'));
            end
            
        end % function writegyrorate

        function isWritten = writeexgrate(thisShimmer, exgRate, chipIdentifier)            % function write exgrate 
            % Writes ExG data rate to Shimmer3 - in Connected state
            if (chipIdentifier == 1 || chipIdentifier == 2)
           
                if ((exgRate == 1) || (exgRate == 2) || (exgRate == 3) || (exgRate == 4) || (exgRate == 5) || (exgRate == 6)  || (exgRate == 0)) % check for valid settings
                    if (thisShimmer.isConnected)
                        if (chipIdentifier ==1)
                            EXG1Config1ClearedDataRateBits = thisShimmer.EXG1Config1;
                            EXG1Config1ClearedDataRateBits = bitand((EXG1Config1ClearedDataRateBits),248);   % Clear the data rate bits of the EXG1Config1 byte
                            EXGConfig1UpdatedDataRateBits = bitor((EXG1Config1ClearedDataRateBits), exgRate); % Updated EXG1Config1 byte
                        else
                            EXG2Config1ClearedDataRateBits = thisShimmer.EXG2Config1;
                            EXG2Config1ClearedDataRateBits = bitand((EXG2Config1ClearedDataRateBits),248);    % Clear the data rate bits of the EXG1Config1 byte
                            EXGConfig1UpdatedDataRateBits = bitor((EXG2Config1ClearedDataRateBits), exgRate); % Updated EXG2Config1 byte
                        end
                                                                                
                            flush(thisShimmer.bluetoothConn, "input");                                   % As a precaution always clear the read data buffer before a write
                            write(thisShimmer.bluetoothConn, thisShimmer.SET_EXG_REGS_COMMAND);      % Send the SET_EXG_REGS_COMMAND to the Shimmer
                            write(thisShimmer.bluetoothConn, char(chipIdentifier-1));                % char(0) selects SENSOR_EXG1, char(1) selects SENSOR_EXG2
                            write(thisShimmer.bluetoothConn, char(0));                               % Start at byte 0
                            write(thisShimmer.bluetoothConn, char(1));                               % and write 1 byte
                            write(thisShimmer.bluetoothConn, char(EXGConfig1UpdatedDataRateBits));   % Write the updated ExG configuration byte to the Shimmer

                            isWritten = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);   % Wait for Acknowledgment from Shimmer

                        if (isWritten == false)
                            fprintf(strcat('Warning: writeexgrate - Set ExG Regs response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                        end
               
                    else
                        isWritten = false;
                        fprintf(strcat('Warning: writeexgrate - Cannot set exg rate for COM ',thisShimmer.name,' as Shimmer is not connected\n'));
                    end
                else
                    isWritten = false;
                    fprintf(strcat('Warning: writeexgrate - Attempt to set exg rate failed due to a request to set the rate to an \n'));
                    fprintf(strcat('invalid setting for Shimmer COM',thisShimmer.name,'.\n'));
                    fprintf(strcat('Valid rate settings are 0 (125 Hz), 1 (250 Hz), 2 (500 Hz), 3 (1000 Hz), 4 (2000 Hz), 5 (4000 Hz) and 6 (8000 Hz).\n'));
                end
             else
                isWritten = false;
                fprintf(strcat('Warning: writeexgrate - Invalid chip selection.\n'));
             end
        end % function write exgrate

        function isRead = readexgrate(thisShimmer, chipIdentifier) % function readexgrate
            % Sends the GET_EXG_REGS_COMMAND to Shimmer3 - in Connected state 
            % Receives ExG data rate and updates the corresponding properties.
            if((chipIdentifier == 1 || chipIdentifier == 2))

                if (thisShimmer.isConnected)
                    flush(thisShimmer.bluetoothConn, "input");                                          % As a precaution always clear the read data buffer before a write
                    write(thisShimmer.bluetoothConn, thisShimmer.GET_EXG_REGS_COMMAND);             % Send the GET_EXG_REGS_COMMAND to the Shimmer
                    write(thisShimmer.bluetoothConn, char(chipIdentifier-1));                       % char(0) selects SENSOR_EXG1, char(1) selects SENSOR_EXG2
                    write(thisShimmer.bluetoothConn, char(0));                                      % Start at byte 0.
                    write(thisShimmer.bluetoothConn, char(1));                                      % Read one byte.
                    isAcknowledged = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);     % Wait for Acknowledgment from Shimmer
                    if (chipIdentifier == 1) 
                        % SENSOR_EXG1
                        if (isAcknowledged == true)
                            [shimmerResponse] = read(thisShimmer.bluetoothConn, 3);        % Read the 3 bytes response from the realterm buffer

                            if ( ~isempty(shimmerResponse) && (shimmerResponse(1) == thisShimmer.EXG_REGS_RESPONSE) )
                                    thisShimmer.EXG1Config1 = shimmerResponse(3);       % Update property EXG1Config1
                                    thisShimmer.EXG1Rate = bitand(thisShimmer.EXG1Config1,7);%Update property EXG1Rate
                                    isRead = true;
                            else
                                thisShimmer.EXG1Config1 = 'Nan';                  % Set the  to 'Nan' to indicate unknown
                                fprintf(strcat('Warning: readexgrate - Get exg regs command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                                isRead = false;
                            end
                        else
                            thisShimmer.EXG1Config1 = 'Nan';                  % Set the  to 'Nan' to indicate unknown
                            fprintf(strcat('Warning: readexgrate - Get exg regs command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                            isRead = false;
                        end
                    else
                        % SENSOR_EXG2
                        if (isAcknowledged == true)
                            [shimmerResponse] = read(thisShimmer.bluetoothConn, 3);        % Read the 3 bytes response from the realterm buffer

                            if (~isempty(shimmerResponse) && (shimmerResponse(1) == thisShimmer.EXG_REGS_RESPONSE))
                                    thisShimmer.EXG2Config1 = shimmerResponse(3);       % Update property EXG2Config1
                                    thisShimmer.EXG2Rate = bitand(thisShimmer.EXG2Config1,7);%Update property EXG2Rate
                                    isRead = true;
                            else
                                thisShimmer.EXG2Config1 = 'Nan';                  % Set the  to 'Nan' to indicate unknown
                                fprintf(strcat('Warning: readexgrate - Get exg regs command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                                isRead = false;
                            end
                        else
                            thisShimmer.EXG2Config1 = 'Nan';                  % Set the  to 'Nan' to indicate unknown
                            fprintf(strcat('Warning: readexgrate - Get exg regs command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                            isRead = false;
                        end
                    end
                else
                    isRead = false;
                    fprintf(strcat('Warning: readexgrate - Cannot get exg rate for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
                end
            else
                isRead = false;
                fprintf(strcat('Warning: readexgrate - Invalid chip selection.\n'));
            end
            
        end % function readexgrate

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

        function [quaternionData,signalName,signalFormat,signalUnit] = getQuaternionData(thisShimmer, dataMode, accelCalibratedData, gyroCalibratedData, magCalibratedData)
            % Get quaternion data from calibrated accelerometer, gyroscope and magnetometer data.
            if (thisShimmer.isStreaming)                     % Shimmer must be in a Streaming state
                if strcmp(dataMode, 'c')
                    
                    quaternionData = thisShimmer.updateQuaternion(accelCalibratedData, gyroCalibratedData, magCalibratedData);
                    
                    signalName{1}='Quaternion 0';
                    signalName{2}='Quaternion 1';
                    signalName{3}='Quaternion 2';
                    signalName{4}='Quaternion 3';
                    signalFormat{1}='CAL';
                    signalFormat{2}='CAL';
                    signalFormat{3}='CAL';
                    signalFormat{4}='CAL';
                    signalUnit{1}='normalised quaternion';
                    signalUnit{2}='normalised quaternion';
                    signalUnit{3}='normalised quaternion';
                    signalUnit{4}='normalised quaternion';
                else
                    disp('Warning: getquaterniondata - Wrong data mode specified');
                end
            else
                quaternionData = [];
                fprintf(strcat('Warning: getquaterniondata - Cannot get data as COM ',thisShimmer.name,' Shimmer is not Streaming'));
            end
        end % function getquaterniondata

        function [accelData,signalName,signalFormat,signalUnit] = getacceldata(thisShimmer, dataMode, parsedData)
            % Get accelerometer data from input parsedData.
            %
            % This is for backward compatability should anyone have used
            % 'Accelerometer X' as a signal name. For Shimmer3 the
            % the signal 'Accelerometer X' is decided based on the selected accel range of
            % the wide range accelerometer. 
            if (thisShimmer.isStreaming)                     % Shimmer must be in a Streaming state
                if (thisShimmer.getaccelrange ==0 && bitand(thisShimmer.EnabledSensors, hex2dec('80'))>0)
                    iAccelXShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer X');            % Determine the column index of the Accelerometer X-axis signal
                    iAccelYShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer Y');            % Determine the column index of the Accelerometer Y-axis signal
                    iAccelZShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer Z');            % Determine the column index of the Accelerometer Z-axis signal
                elseif (bitand(thisShimmer.EnabledSensors, hex2dec('1000'))>0)
                    iAccelXShimmer = thisShimmer.getsignalindex('Wide Range Accelerometer X');            % Determine the column index of the Accelerometer X-axis signal
                    iAccelYShimmer = thisShimmer.getsignalindex('Wide Range Accelerometer Y');            % Determine the column index of the Accelerometer Y-axis signal
                    iAccelZShimmer = thisShimmer.getsignalindex('Wide Range Accelerometer Z');            % Determine the column index of the Accelerometer Z-axis signal
                elseif (bitand(thisShimmer.EnabledSensors, hex2dec('80'))>0)
                    iAccelXShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer X');            % Determine the column index of the Accelerometer X-axis signal
                    iAccelYShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer Y');            % Determine the column index of the Accelerometer Y-axis signal
                    iAccelZShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer Z');            % Determine the column index of the Accelerometer Z-axis signal
                end
                if strcmp(dataMode,'a')
                    accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                    if ((thisShimmer.getaccelrange ==0 && bitand(thisShimmer.EnabledSensors, hex2dec('80'))>0))
                        accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.AccelCalParametersAM,thisShimmer.AccelCalParametersSM,thisShimmer.AccelCalParametersOV);
                    elseif (bitand(thisShimmer.EnabledSensors, hex2dec('1000'))>0)
                        accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.DAccelCalParametersAM,thisShimmer.DAccelCalParametersSM,thisShimmer.DAccelCalParametersOV);
                    else
                        accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.AccelCalParametersAM,thisShimmer.AccelCalParametersSM,thisShimmer.AccelCalParametersOV);
                    end
                    accelData=[accelUncalibratedData accelCalibratedData];
                    signalName{1}='Accelerometer X';
                    signalName{2}='Accelerometer Y';
                    signalName{3}='Accelerometer Z';
                    signalFormat{1}='RAW';
                    signalFormat{2}='RAW';
                    signalFormat{3}='RAW';
                    signalUnit{1}='no units';
                    signalUnit{2}='no units';
                    signalUnit{3}='no units';
                    if thisShimmer.DefaultAccelCalibrationParameters==true
                        signalName{4}='Accelerometer X';
                        signalName{5}='Accelerometer Y';
                        signalName{6}='Accelerometer Z';
                        signalFormat{4}='CAL';
                        signalFormat{5}='CAL';
                        signalFormat{6}='CAL';
                        signalUnit{4}='m/(s^2) *';  % *indicates that default calibration parameters were used to calibrate the sensor data
                        signalUnit{5}='m/(s^2) *';
                        signalUnit{6}='m/(s^2) *';
                    else
                        signalName{4}='Accelerometer X';
                        signalName{5}='Accelerometer Y';
                        signalName{6}='Accelerometer Z';
                        signalFormat{4}='CAL';
                        signalFormat{5}='CAL';
                        signalFormat{6}='CAL';
                        signalUnit{4}='m/(s^2)';
                        signalUnit{5}='m/(s^2)';
                        signalUnit{6}='m/(s^2)';
                    end
                    
                elseif strcmp(dataMode,'u')
                    accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                    accelData=accelUncalibratedData;
                    signalName{1}='Accelerometer X';
                    signalName{2}='Accelerometer Y';
                    signalName{3}='Accelerometer Z';
                    signalFormat{1}='RAW';
                    signalFormat{2}='RAW';
                    signalFormat{3}='RAW';
                    signalUnit{1}='no units';
                    signalUnit{2}='no units';
                    signalUnit{3}='no units';
                    
                elseif strcmp(dataMode,'c')
                    accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                    if ((thisShimmer.getaccelrange ==0))
                        accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.AccelCalParametersAM,thisShimmer.AccelCalParametersSM,thisShimmer.AccelCalParametersOV);
                    elseif (thisShimmer.getaccelrange ~=0)
                        accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.DAccelCalParametersAM,thisShimmer.DAccelCalParametersSM,thisShimmer.DAccelCalParametersOV);
                    end
                    accelData=accelCalibratedData;
                    if thisShimmer.DefaultAccelCalibrationParameters==true
                        signalName{1}='Accelerometer X';
                        signalName{2}='Accelerometer Y';
                        signalName{3}='Accelerometer Z';
                        signalFormat{1}='CAL';
                        signalFormat{2}='CAL';
                        signalFormat{3}='CAL';
                        signalUnit{1}='m/(s^2) *';  % *indicates that default calibration parameters were used to calibrate the sensor data
                        signalUnit{2}='m/(s^2) *';
                        signalUnit{3}='m/(s^2) *';
                    else
                        signalName{1}='Accelerometer X';
                        signalName{2}='Accelerometer Y';
                        signalName{3}='Accelerometer Z';
                        signalFormat{1}='CAL';
                        signalFormat{2}='CAL';
                        signalFormat{3}='CAL';
                        signalUnit{1}='m/(s^2)';
                        signalUnit{2}='m/(s^2)';
                        signalUnit{3}='m/(s^2)';
                    end
                else
                    disp('Wrong data mode specified');
                end
            else
                accelData = [];
                fprintf(strcat('Warning: getacceldata - Cannot get data as COM ',thisShimmer.name,' Shimmer is not Streaming'));
            end
        end
        
        function [accelData,signalName,signalFormat,signalUnit] = getlownoiseacceldata(thisShimmer, dataMode, parsedData)
             % Get low noise accelerometer data from input parsedData.
            iAccelXShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer X');            % Determine the column index of the Accelerometer X-axis signal
            iAccelYShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer Y');            % Determine the column index of the Accelerometer Y-axis signal
            iAccelZShimmer = thisShimmer.getsignalindex('Low Noise Accelerometer Z');            % Determine the column index of the Accelerometer Z-axis signal
            if strcmp(dataMode,'a')
                accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.AccelCalParametersAM,thisShimmer.AccelCalParametersSM,thisShimmer.AccelCalParametersOV);
                accelData=[accelUncalibratedData accelCalibratedData];
                signalName{1}='Low Noise Accelerometer X';
                signalName{2}='Low Noise Accelerometer Y';
                signalName{3}='Low Noise Accelerometer Z';
                signalFormat{1}='RAW';
                signalFormat{2}='RAW';
                signalFormat{3}='RAW';
                signalUnit{1}='no units';
                signalUnit{2}='no units';
                signalUnit{3}='no units';
                if thisShimmer.DefaultAccelCalibrationParameters==true
                    signalName{4}='Low Noise Accelerometer X';
                    signalName{5}='Low Noise Accelerometer Y';
                    signalName{6}='Low Noise Accelerometer Z';
                    signalFormat{4}='CAL';
                    signalFormat{5}='CAL';
                    signalFormat{6}='CAL';
                    signalUnit{4}='m/(s^2) *';  % *indicates that default calibration parameters were used to calibrate the sensor data
                    signalUnit{5}='m/(s^2) *';
                    signalUnit{6}='m/(s^2) *';
                else
                    signalName{4}='Low Noise Accelerometer X';
                    signalName{5}='Low Noise Accelerometer Y';
                    signalName{6}='Low Noise Accelerometer Z';
                    signalFormat{4}='CAL';
                    signalFormat{5}='CAL';
                    signalFormat{6}='CAL';
                    signalUnit{4}='m/(s^2)';
                    signalUnit{5}='m/(s^2)';
                    signalUnit{6}='m/(s^2)';
                end
                
            elseif strcmp(dataMode,'u')
                accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                accelData=accelUncalibratedData;
                signalName{1}='Low Noise Accelerometer X';
                signalName{2}='Low Noise Accelerometer Y';
                signalName{3}='Low Noise Accelerometer Z';
                signalFormat{1}='RAW';
                signalFormat{2}='RAW';
                signalFormat{3}='RAW';
                signalUnit{1}='no units';
                signalUnit{2}='no units';
                signalUnit{3}='no units';
                
            elseif strcmp(dataMode,'c')
                accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.AccelCalParametersAM,thisShimmer.AccelCalParametersSM,thisShimmer.AccelCalParametersOV);
                accelData=accelCalibratedData;
                if thisShimmer.DefaultAccelCalibrationParameters==true
                    signalName{1}='Low Noise Accelerometer X';
                    signalName{2}='Low Noise Accelerometer Y';
                    signalName{3}='Low Noise Accelerometer Z';
                    signalFormat{1}='CAL';
                    signalFormat{2}='CAL';
                    signalFormat{3}='CAL';
                    signalUnit{1}='m/(s^2) *';  % *indicates that default calibration parameters were used to calibrate the sensor data
                    signalUnit{2}='m/(s^2) *';
                    signalUnit{3}='m/(s^2) *';
                else
                    signalName{1}='Low Noise Accelerometer X';
                    signalName{2}='Low Noise Accelerometer Y';
                    signalName{3}='Low Noise Accelerometer Z';
                    signalFormat{1}='CAL';
                    signalFormat{2}='CAL';
                    signalFormat{3}='CAL';
                    signalUnit{1}='m/(s^2)';
                    signalUnit{2}='m/(s^2)';
                    signalUnit{3}='m/(s^2)';
                end
            else
                disp('Warning: getlownoiseacceldata - Wrong data mode specified');
            end
        end
        
        function [accelData,signalName,signalFormat,signalUnit] = getwiderangeacceldata(thisShimmer, dataMode, parsedData)
            % Get wide range accelerometer data from input parsedData.
            iAccelXShimmer = thisShimmer.getsignalindex('Wide Range Accelerometer X');            % Determine the column index of the Accelerometer X-axis signal
            iAccelYShimmer = thisShimmer.getsignalindex('Wide Range Accelerometer Y');            % Determine the column index of the Accelerometer Y-axis signal
            iAccelZShimmer = thisShimmer.getsignalindex('Wide Range Accelerometer Z');            % Determine the column index of the Accelerometer Z-axis signal
            if strcmp(dataMode,'a')
                accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.DAccelCalParametersAM,thisShimmer.DAccelCalParametersSM,thisShimmer.DAccelCalParametersOV);
                accelData=[accelUncalibratedData accelCalibratedData];
                signalName{1}='Wide Range Accelerometer X';
                signalName{2}='Wide Range Accelerometer Y';
                signalName{3}='Wide Range Accelerometer Z';
                signalFormat{1}='RAW';
                signalFormat{2}='RAW';
                signalFormat{3}='RAW';
                signalUnit{1}='no units';
                signalUnit{2}='no units';
                signalUnit{3}='no units';
                if thisShimmer.DefaultDAccelCalibrationParameters==true
                    signalName{4}='Wide Range Accelerometer X';
                    signalName{5}='Wide Range Accelerometer Y';
                    signalName{6}='Wide Range Accelerometer Z';
                    signalFormat{4}='CAL';
                    signalFormat{5}='CAL';
                    signalFormat{6}='CAL';
                    signalUnit{4}='m/(s^2) *';  % *indicates that default calibration parameters were used to calibrate the sensor data
                    signalUnit{5}='m/(s^2) *';
                    signalUnit{6}='m/(s^2) *';
                else
                    signalName{4}='Wide Range Accelerometer X';
                    signalName{5}='Wide Range Accelerometer Y';
                    signalName{6}='Wide Range Accelerometer Z';
                    signalFormat{4}='CAL';
                    signalFormat{5}='CAL';
                    signalFormat{6}='CAL';
                    signalUnit{4}='m/(s^2)';
                    signalUnit{5}='m/(s^2)';
                    signalUnit{6}='m/(s^2)';
                end
                
            elseif strcmp(dataMode,'u')
                accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                accelData=accelUncalibratedData;
                signalName{1}='Wide Range Accelerometer X';
                signalName{2}='Wide Range Accelerometer Y';
                signalName{3}='Wide Range Accelerometer Z';
                signalFormat{1}='RAW';
                signalFormat{2}='RAW';
                signalFormat{3}='RAW';
                signalUnit{1}='no units';
                signalUnit{2}='no units';
                signalUnit{3}='no units';
                
            elseif strcmp(dataMode,'c')
                accelUncalibratedData=double(parsedData(:,[iAccelXShimmer iAccelYShimmer iAccelZShimmer]));
                accelCalibratedData = thisShimmer.calibrateinertialsensordata(accelUncalibratedData,thisShimmer.DAccelCalParametersAM,thisShimmer.DAccelCalParametersSM,thisShimmer.DAccelCalParametersOV);
                accelData=accelCalibratedData;
                if thisShimmer.DefaultDAccelCalibrationParameters==true
                    signalName{1}='Wide Range Accelerometer X';
                    signalName{2}='Wide Range Accelerometer Y';
                    signalName{3}='Wide Range Accelerometer Z';
                    signalFormat{1}='CAL';
                    signalFormat{2}='CAL';
                    signalFormat{3}='CAL';
                    signalUnit{1}='m/(s^2) *';  % *indicates that default calibration parameters were used to calibrate the sensor data
                    signalUnit{2}='m/(s^2) *';
                    signalUnit{3}='m/(s^2) *';
                else
                    signalName{1}='Wide Range Accelerometer X';
                    signalName{2}='Wide Range Accelerometer Y';
                    signalName{3}='Wide Range Accelerometer Z';
                    signalFormat{1}='CAL';
                    signalFormat{2}='CAL';
                    signalFormat{3}='CAL';
                    signalUnit{1}='m/(s^2)';
                    signalUnit{2}='m/(s^2)';
                    signalUnit{3}='m/(s^2)';
                end
            else
                disp('Warning: getwiderangeacceldata - Wrong data mode specified');
            end
        end
        
        function [magData,signalName,signalFormat,signalUnit] = getmagdata(thisShimmer, dataMode, parsedData)
             % Get magnetometer data from input parsedData.
            if (thisShimmer.isStreaming)                     % Shimmer must be in a Streaming state
                iMagXShimmer = thisShimmer.getsignalindex('Magnetometer X');            % Determine the column index of the Magnetometer X-axis signal
                iMagYShimmer = thisShimmer.getsignalindex('Magnetometer Y');            % Determine the column index of the Magnetometer Y-axis signal
                iMagZShimmer = thisShimmer.getsignalindex('Magnetometer Z');            % Determine the column index of the Magnetometer Z-axis signal
                
                if strcmp(dataMode,'a')
                    magUncalibratedData=double(parsedData(:,[iMagXShimmer iMagYShimmer iMagZShimmer]));
                    magCalibratedData = thisShimmer.calibrateinertialsensordata(magUncalibratedData,thisShimmer.MagneCalParametersAM,thisShimmer.MagneCalParametersSM,thisShimmer.MagneCalParametersOV);
                    magData=[magUncalibratedData magCalibratedData];
                    signalName{1}='Magnetometer X';
                    signalName{2}='Magnetometer Y';
                    signalName{3}='Magnetometer Z';
                    signalFormat{1}='RAW';
                    signalFormat{2}='RAW';
                    signalFormat{3}='RAW';
                    signalUnit{1}='no units';
                    signalUnit{2}='no units';
                    signalUnit{3}='no units';
                    if thisShimmer.DefaultMagneCalibrationParameters==true
                        signalName{4}='Magnetometer X';
                        signalName{5}='Magnetometer Y';
                        signalName{6}='Magnetometer Z';
                        signalFormat{4}='CAL';
                        signalFormat{5}='CAL';
                        signalFormat{6}='CAL';
                        signalUnit{4}='local flux *'; % *indicates that default calibration parameters were used to calibrate the sensor data
                        signalUnit{5}='local flux *';
                        signalUnit{6}='local flux *';
                    else
                        signalName{4}='Magnetometer X';
                        signalName{5}='Magnetometer Y';
                        signalName{6}='Magnetometer Z';
                        signalFormat{4}='CAL';
                        signalFormat{5}='CAL';
                        signalFormat{6}='CAL';
                        signalUnit{4}='local flux';
                        signalUnit{5}='local flux';
                        signalUnit{6}='local flux';
                    end
                    
                elseif strcmp(dataMode,'u')
                    magUncalibratedData=double(parsedData(:,[iMagXShimmer iMagYShimmer iMagZShimmer]));
                    magData=magUncalibratedData;
                    signalName{1}='Magnetometer X';
                    signalName{2}='Magnetometer Y';
                    signalName{3}='Magnetometer Z';
                    signalFormat{1}='RAW';
                    signalFormat{2}='RAW';
                    signalFormat{3}='RAW';
                    signalUnit{1}='no units';
                    signalUnit{2}='no units';
                    signalUnit{3}='no units';
                    
                elseif strcmp(dataMode,'c')
                    if thisShimmer.DefaultMagneCalibrationParameters==true
                        signalName{1}='Magnetometer X';
                        signalName{2}='Magnetometer Y';
                        signalName{3}='Magnetometer Z';
                        signalFormat{1}='CAL';
                        signalFormat{2}='CAL';
                        signalFormat{3}='CAL';
                        signalUnit{1}='local flux *'; % *indicates that default calibration parameters were used to calibrate the sensor data
                        signalUnit{2}='local flux *';
                        signalUnit{3}='local flux *';
                    else
                        signalName{1}='Magnetometer X';
                        signalName{2}='Magnetometer Y';
                        signalName{3}='Magnetometer Z';
                        signalFormat{1}='CAL';
                        signalFormat{2}='CAL';
                        signalFormat{3}='CAL';
                        signalUnit{1}='local flux';
                        signalUnit{2}='local flux';
                        signalUnit{3}='local flux';
                    end
                    
                    magUncalibratedData=double(parsedData(:,[iMagXShimmer iMagYShimmer iMagZShimmer]));
                    magCalibratedData = thisShimmer.calibrateinertialsensordata(magUncalibratedData,thisShimmer.MagneCalParametersAM,thisShimmer.MagneCalParametersSM,thisShimmer.MagneCalParametersOV);
                    magData=magCalibratedData;
                    
                else
                    disp('Warning: getmagdata - Wrong data mode specified');
                end
            else
                magData = [];
                fprintf(strcat('Warning: getmagdata - Cannot get data as COM ',thisShimmer.name,' Shimmer is not Streaming'));
            end
        end
                        
        function [gyroData, signalName, signalFormat, signalUnit] = getgyrodata(thisShimmer, dataMode, parsedData)
             % Get gyroscope data from input parsedData.
            if (thisShimmer.isStreaming)                     % Shimmer must be in a Streaming state
                iGyroXShimmer = thisShimmer.getsignalindex('Gyroscope X');            % Determine the column index of the Gyroscope X-axis signal
                iGyroYShimmer = thisShimmer.getsignalindex('Gyroscope Y');            % Determine the column index of the Gyroscope Y-axis signal
                iGyroZShimmer = thisShimmer.getsignalindex('Gyroscope Z');            % Determine the column index of the Gyroscope Z-axis signal
                
                if strcmp(dataMode,'a')
                    gyroUncalibratedData=double(parsedData(:,[iGyroXShimmer iGyroYShimmer iGyroZShimmer]));
                    gyroCalibratedData = thisShimmer.calibrateinertialsensordata(gyroUncalibratedData,thisShimmer.GyroCalParametersAM,thisShimmer.GyroCalParametersSM,thisShimmer.GyroCalParametersOV);
                    gyroData=[gyroUncalibratedData gyroCalibratedData];
                    signalName{1}='Gyroscope X';
                    signalName{2}='Gyroscope Y';
                    signalName{3}='Gyroscope Z';
                    signalFormat{1}='RAW';
                    signalFormat{2}='RAW';
                    signalFormat{3}='RAW';
                    signalUnit{1}='no units';
                    signalUnit{2}='no units';
                    signalUnit{3}='no units';
                    if thisShimmer.DefaultGyroCalibrationParameters==true
                        signalName{4}='Gyroscope X';
                        signalName{5}='Gyroscope Y';
                        signalName{6}='Gyroscope Z';
                        signalFormat{4}='CAL';
                        signalFormat{5}='CAL';
                        signalFormat{6}='CAL';
                        signalUnit{4}='degrees/s *'; % *indicates that default calibration parameters were used to calibrate the sensor data
                        signalUnit{5}='degrees/s *';
                        signalUnit{6}='degrees/s *';
                    else
                        signalName{4}='Gyroscope X';
                        signalName{5}='Gyroscope Y';
                        signalName{6}='Gyroscope Z';
                        signalFormat{4}='CAL';
                        signalFormat{5}='CAL';
                        signalFormat{6}='CAL';
                        signalUnit{4}='degrees/s'; % *indicates that default calibration parameters were used to calibrate the sensor data
                        signalUnit{5}='degrees/s';
                        signalUnit{6}='degrees/s';
                    end
                elseif strcmp(dataMode,'u')
                    gyroUncalibratedData=double(parsedData(:,[iGyroXShimmer iGyroYShimmer iGyroZShimmer]));
                    gyroData=gyroUncalibratedData;
                    signalName{1}='Gyroscope X';
                    signalName{2}='Gyroscope Y';
                    signalName{3}='Gyroscope Z';
                    signalFormat{1}='RAW';
                    signalFormat{2}='RAW';
                    signalFormat{3}='RAW';
                    signalUnit{1}='no units';
                    signalUnit{2}='no units';
                    signalUnit{3}='no units';
                    
                elseif strcmp(dataMode,'c')
                    gyroUncalibratedData=double(parsedData(:,[iGyroXShimmer iGyroYShimmer iGyroZShimmer]));
                    gyroCalibratedData = thisShimmer.calibrateinertialsensordata(gyroUncalibratedData,thisShimmer.GyroCalParametersAM,thisShimmer.GyroCalParametersSM,thisShimmer.GyroCalParametersOV);
                    gyroData=gyroCalibratedData;
                    if thisShimmer.DefaultGyroCalibrationParameters==true
                        signalName{1}='Gyroscope X';
                        signalName{2}='Gyroscope Y';
                        signalName{3}='Gyroscope Z';
                        signalFormat{1}='CAL';
                        signalFormat{2}='CAL';
                        signalFormat{3}='CAL';
                        signalUnit{1}='degrees/s *'; % *indicates that default calibration parameters were used to calibrate the sensor data
                        signalUnit{2}='degrees/s *';
                        signalUnit{3}='degrees/s *';
                    else
                        signalName{1}='Gyroscope X';
                        signalName{2}='Gyroscope Y';
                        signalName{3}='Gyroscope Z';
                        signalFormat{1}='CAL';
                        signalFormat{2}='CAL';
                        signalFormat{3}='CAL';
                        signalUnit{1}='degrees/s'; % *indicates that default calibration parameters were used to calibrate the sensor data
                        signalUnit{2}='degrees/s';
                        signalUnit{3}='degrees/s';
                    end
                else
                    disp('Warning: getgyrodata - Wrong data mode specified');
                end
            else
                gyroData = [];
                fprintf(strcat('Warning: getgyrodata - Cannot get data as COM ',thisShimmer.name,' Shimmer is not Streaming'));
            end
        end

        function noMotion = nomotiondetect(thisShimmer)
            % Detects if Shimmer is not moving.
            stdGyroBuffer = std(thisShimmer.GyroBuffer);
            if(max(stdGyroBuffer) <= thisShimmer.GyroMotionThreshold)
                noMotion = true;
            else
                noMotion = false;
            end
        end % function nomotiondetect

        function [] = estimategyrooffset(thisShimmer)
            % Estimates Gyroscope offset.
            meanGyroBuffer = mean(thisShimmer.GyroBuffer,1);
            
            thisShimmer.GyroCalParametersOV = meanGyroBuffer';
        end % function estimategyrooffset

        function [parsedData,systemTime] = capturedata(thisShimmer)
            % Reads data from the serial buffer, frames and parses these data.
            parsedData=[];
            systemTime = 0;
            
            if (thisShimmer.isStreaming)                        % TRUE if the Shimmer is in a Streaming state
                
                serialData = [];

                numBytes = thisShimmer.bluetoothConn.NumBytesAvailable;
                if (numBytes == 0)
                    numBytes = 1;
                end
                
                serialData = read(thisShimmer.bluetoothConn, numBytes);  % Read all available serial data from the com port
                flush(thisShimmer.bluetoothConn, "input");

                %Change columns to rows
                swappedData = zeros(numBytes,1);
                for dataSample = 1:1:numBytes
                    swappedData(dataSample,1) = serialData(1,dataSample);
                end

                serialData = swappedData;

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
                        [quaternionData,tempSignalName,tempSignalFormat,tempSignalUnit]=getQuaternionData(thisShimmer,'c',accelData,gyroData,magData);
                        
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

        function iSignal = getsignalindex(thisShimmer,signalName)
            %GETSIGNALINDEX - Get the index of a sensor signal
            %
            %   SIGNALINDEX = GETSIGNALINDEX(SIGNALNAME) returns the index of
            %   the sensor signal corresponding to the name SIGNALNAME.
            %
            %   SYNOPSIS: iSignal = thisShimmer.getsignalindex(signalName)
            %
            %   INPUT: signalName - String value that defines the name of the
            %                       data signal of interest.
            %                       Valid values are 'Accelerometer X',
            %                       'Accelerometer Y', 'Accelerometer Z',
            %                       'Gyroscope X', 'Gyroscope Y', 'Gyroscope Z',
            %                       'Magnetometer X', 'Magnetometer Y',
            %                       'Magnetometer Z', 'ECG RA-LL', 'ECG LA-LL',
            %                       'GSR Raw', 'GSR Res', 'EMG', 'ExpBoard A0',
            %                       'ExpBoard A7', 'Strain Gauge High',
            %                       'Strain Gauge Low' and 'Heart Rate'.
            %
            %   OUTPUT: signalName - Signed non-zero integer value that defines
            %                        the index of the data signal of interest.
            %
            %   EXAMPLE: iSignal = shimmer1.getsignalindex('Accelerometer X');
            %
            %   See also setenabledsensors getenabledsignalnames getsignalname
            
            iSignal = find(strcmp(thisShimmer.SignalNameArray,signalName));% Determine the column index of the signal defined in signalName
        end

        function CalibratedData = calibrateinertialsensordata(thisShimmer,UncalibratedData,R,K,B)
            % Calibration of inertial sensor data - calibrates input UncalibratedData with parameters:
            % R,K,B.
            %
            % Based on the theory outlined by Ferraris F, Grimaldi U, and Parvis M.
            % in "Procedure for effortless in-field calibration of three-axis rate gyros and accelerometers" Sens. Mater. 1995; 7: 311-30.
            % For a multiple samples of 3 axis data......
            %C = [R^(-1)] .[K^(-1)] .([U]-[B])
            
            %where.....
            %[C] -> [3 x n] Calibrated Data Matrix
            %[U] -> [3 x n] Uncalibrated Data Matrix
            %[B] ->  [3 x n] Offset Vector Matrix
            %[R] -> [3x3] Alignment Matrix
            %[K] -> [3x3] Sensitivity Matrix
            %n = Number of Samples
            CalibratedData=((R^-1)*(K^-1)*(UncalibratedData'-B*ones(1,length(UncalibratedData(:,1)))))';
        end

        function isRead = inquiry(thisShimmer)
            % Sends the INQUIRY_COMMAND to Shimmer - in Connected state 
            % Receives Inquire Response and call the function
            % parseinquiryresponse with the just received Inquire Response 
            % as input argument.
            if (thisShimmer.isConnected)
                flush(thisShimmer.bluetoothConn, "input");                                         % As a precaution always clear the read data buffer before a write
                write(thisShimmer.bluetoothConn, thisShimmer.INQUIRY_COMMAND);                 % Send the Inquiry Command to the Shimmer
                
                isAcknowledged = waitForAck(thisShimmer, thisShimmer.DEFAULT_TIMEOUT);    % Wait for Acknowledgment from Shimmer
                
                if (isAcknowledged == true)
                    [shimmerResponse] = read(thisShimmer.bluetoothConn, thisShimmer.bluetoothConn.NumBytesAvailable);     % Read Inquiry Command response from the bluetooth buffer
                    
                    if ~isempty(shimmerResponse)
                        
                        if (shimmerResponse(1) == thisShimmer.INQUIRY_RESPONSE)
                            parseinquiryresponse(thisShimmer, shimmerResponse);
                            isRead = true;
                        else
                            fprintf(strcat('Warning: inquiry - Inquiry command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                            isRead = false;
                        end
                    else
                        fprintf(strcat('Warning: inquiry - Inquiry command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                        isRead = false;
                    end
                    
                else
                    fprintf(strcat('Warning: inquiry - Inquiry command response expected but not returned for Shimmer COM',thisShimmer.name,'.\n'));
                    isRead = false;
                end
            else
                isRead = false;
                fprintf(strcat('Warning: inquiry - Cannot get inquiry reponse for COM ',thisShimmer.name,' as Shimmer is not connected.\n'));
            end
        end % function inquiry

        function parseinquiryresponse(thisShimmer, inquiryResponse)
            % Parses the Inquiry Response inquiryResponse and updates
            % properties accordingly.
            thisShimmer.SamplingRate = 32768.0 /double(int32(256*uint16(inquiryResponse(3)))+int32(inquiryResponse(2)));
            nChannels = inquiryResponse(8);
            thisShimmer.BufferSize = inquiryResponse(9);                                        % Buffer size is currently not used
            nIterations = 0;
            while(length(inquiryResponse) < 9+nChannels && nIterations < 4)
                [tempResponse] = read(thisShimmer.bluetoothConn, thisShimmer.bluetoothConn.NumBytesAvailable);     % Read Inquiry Command response from the bluetooth buffer
                inquiryResponse = [inquiryResponse; tempResponse];
                nIterations = nIterations + 1;
            end
            signalIDArray = inquiryResponse(10:9+nChannels);
            thisShimmer.ConfigByte0 = double(inquiryResponse(4));                               % ConfigByte0
            thisShimmer.ConfigByte1 = double(inquiryResponse(5));                               % ConfigByte1
            thisShimmer.ConfigByte2 = double(inquiryResponse(6));                               % ConfigByte2
            thisShimmer.ConfigByte3 = double(inquiryResponse(7));                               % ConfigByte3              
            thisShimmer.AccelWideRangeHRMode = bitand(thisShimmer.ConfigByte0,1);               % High Resolution mode LSM303DLHC/LSM303AHTR
            thisShimmer.AccelWideRangeLPMode = bitand(bitshift(thisShimmer.ConfigByte0,-1),1);  % Low Power mode LSM303DLHC/LSM303AHTR
            thisShimmer.AccelRange = bitand(bitshift(thisShimmer.ConfigByte0,-2),3); 
            thisShimmer.AccelWideRangeDataRate = bitand(bitshift(thisShimmer.ConfigByte0,-4),15);   
            thisShimmer.GyroRate = bitand(thisShimmer.ConfigByte1,255);                         % MPU9150 sampling rate 
            thisShimmer.GyroRange = bitand(thisShimmer.ConfigByte2,3);
            thisShimmer.MagRate =  bitand(bitshift(thisShimmer.ConfigByte2,-2),7);
            thisShimmer.MagRange = bitand(bitshift(thisShimmer.ConfigByte2,-5),7); 
            thisShimmer.InternalExpPower = bitand(thisShimmer.ConfigByte3,1);
            thisShimmer.GsrRange = bitand(bitshift(thisShimmer.ConfigByte3,-1),7);
            thisShimmer.PressureResolution = bitand(bitshift(thisShimmer.ConfigByte3,-4),3);
            interpretdatapacketformat(thisShimmer,signalIDArray);  
            
        end % parseinquiryresponse

        function interpretdatapacketformat(thisShimmer,signalIDArray)
            % Is called by the function parseinquiryresponse and interprets
            % the data packet format based on the input signalIDArray.
            enabledSensors = 0;                                            % Enabled/Disabled Sensors bitmap
            nBytesDataPacket = 1;                                          % Initially Number of Bytes in Data Packet = 1 (Packet Type byte)

            % Get Data Packet Format values for Timestamp
            signalNameArray(1) = cellstr('Timestamp');                     % Cell array containing the names of the signal in each data channel
            
            % Timestamp value is of type unsigned 16bit
            nBytesDataPacket = nBytesDataPacket+3;                 % Three byte timestamp has been introduced with FirmwareCompatibilityCode == 6
            signalDataTypeArray(1) = cellstr('u24');               % Cell array containing the data type of the signal in each data channel
                
            % Get Data Packet Format values for other enabled data signals
            for i = 1:length(signalIDArray)
                
                hexSignalID=dec2hex(signalIDArray(i));                     % Extract signalID(i) in hex formnat
                
                switch hexSignalID
                    case ('0')
                        signalNameArray(i+1) = cellstr('Low Noise Accelerometer X');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('80'));
                    case ('1')
                        signalNameArray(i+1) = cellstr('Low Noise Accelerometer Y');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('80'));
                    case ('2')
                        signalNameArray(i+1) = cellstr('Low Noise Accelerometer Z');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('80'));
                    case ('3')
                        signalNameArray(i+1) = cellstr('Battery Voltage');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('2000'));
                    case ('4')
                        signalNameArray(i+1) = cellstr('Wide Range Accelerometer X');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('1000'));
                    case ('5')
                        signalNameArray(i+1) = cellstr('Wide Range Accelerometer Y');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('1000'));
                    case ('6')
                        signalNameArray(i+1) = cellstr('Wide Range Accelerometer Z');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('1000'));
                    case ('7')
                        signalNameArray(i+1) = cellstr('Magnetometer X');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('20'));
                    case ('8')
                        signalNameArray(i+1) = cellstr('Magnetometer Y');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('20'));
                    case ('9')
                        signalNameArray(i+1) = cellstr('Magnetometer Z');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('20'));
                    case ('A')
                        signalNameArray(i+1) = cellstr('Gyroscope X');
                        signalDataTypeArray(i+1) = cellstr('i16*');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('40'));
                    case ('B')
                        signalNameArray(i+1) = cellstr('Gyroscope Y');
                        signalDataTypeArray(i+1) = cellstr('i16*');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('40'));
                    case ('C')
                        signalNameArray(i+1) = cellstr('Gyroscope Z');
                        signalDataTypeArray(i+1) = cellstr('i16*');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('40'));
                    case ('D')
                        signalNameArray(i+1) = cellstr('External ADC A7');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('2'));
                    case ('E')
                        signalNameArray(i+1) = cellstr('External ADC A6');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('1'));
                    case ('F')
                        signalNameArray(i+1) = cellstr('External ADC A15');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('800'));
                    case ('10')
                        signalNameArray(i+1) = cellstr('Internal ADC A1');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('400'));
                    case ('11')
                        signalNameArray(i+1) = cellstr('Internal ADC A12');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('200'));
                    case ('12')
                        signalNameArray(i+1) = cellstr('Internal ADC A13');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('100'));
                    case ('13')
                        signalNameArray(i+1) = cellstr('Internal ADC A14');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('800000'));
                    case ('14')
                        signalNameArray(i+1) = cellstr('Alternative Accelerometer X');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('400000'));
                    case ('15')
                        signalNameArray(i+1) = cellstr('Alternative Accelerometer Y');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('400000'));
                    case ('16')
                        signalNameArray(i+1) = cellstr('Alternative Accelerometer Z');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('400000'));
                    case ('17')
                        signalNameArray(i+1) = cellstr('Alternative Magnetometer X');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('200000'));
                    case ('18')
                        signalNameArray(i+1) = cellstr('Alternative Magnetometer Y');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('200000'));
                    case ('19')
                        signalNameArray(i+1) = cellstr('Alternative Magnetometer Z');
                        signalDataTypeArray(i+1) = cellstr('i16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('200000'));
                    case ('1A')
                        signalNameArray(i+1) = cellstr('Temperature');
                        signalDataTypeArray(i+1) = cellstr('u16*');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('40000'));
                    case ('1B')
                        signalNameArray(i+1) = cellstr('Pressure');
                        signalDataTypeArray(i+1) = cellstr('u24*');
                        nBytesDataPacket=nBytesDataPacket+3;
                        enabledSensors = bitor(enabledSensors,hex2dec('40000'));
                    case ('1C')
                        signalNameArray(i+1) = cellstr('GSR Raw');
                        signalDataTypeArray(i+1) = cellstr('u16');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('04'));
                    case ('1D')
                        signalNameArray(i+1) = cellstr('EXG1 STA');
                        signalDataTypeArray(i+1) = cellstr('u8');
                        nBytesDataPacket=nBytesDataPacket+1;
                    case ('1E')
                        signalNameArray(i+1) = cellstr('EXG1 CH1');
                        signalDataTypeArray(i+1) = cellstr('i24*');
                        nBytesDataPacket=nBytesDataPacket+3;
                        enabledSensors = bitor(enabledSensors,hex2dec('10'));
                    case ('1F')
                        signalNameArray(i+1) = cellstr('EXG1 CH2');
                        signalDataTypeArray(i+1) = cellstr('i24*');
                        nBytesDataPacket=nBytesDataPacket+3;
                        enabledSensors = bitor(enabledSensors,hex2dec('10'));
                    case ('20')
                        signalNameArray(i+1) = cellstr('EXG2 STA');
                        signalDataTypeArray(i+1) = cellstr('u8');
                        nBytesDataPacket=nBytesDataPacket+1;
                    case ('21')
                        signalNameArray(i+1) = cellstr('EXG2 CH1'); 
                        signalDataTypeArray(i+1) = cellstr('i24*');
                        nBytesDataPacket=nBytesDataPacket+3;
                        enabledSensors = bitor(enabledSensors,hex2dec('08'));
                    case ('22')
                        signalNameArray(i+1) = cellstr('EXG2 CH2');
                        signalDataTypeArray(i+1) = cellstr('i24*');
                        nBytesDataPacket=nBytesDataPacket+3;
                        enabledSensors = bitor(enabledSensors,hex2dec('08'));
                    case ('23')
                        signalNameArray(i+1) = cellstr('EXG1 CH1 16BIT');
                        signalDataTypeArray(i+1) = cellstr('i16*');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('100000'));
                    case ('24')
                        signalNameArray(i+1) = cellstr('EXG1 CH2 16BIT');
                        signalDataTypeArray(i+1) = cellstr('i16*');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('100000'));
                    case ('25')
                        signalNameArray(i+1) = cellstr('EXG2 CH1 16BIT');
                        signalDataTypeArray(i+1) = cellstr('i16*');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('080000'));
                    case ('26')
                        signalNameArray(i+1) = cellstr('EXG2 CH2 16BIT');
                        signalDataTypeArray(i+1) = cellstr('i16*');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('080000'));
                    case ('27')
                        signalNameArray(i+1) = cellstr('Bridge Amplifier High');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('8000'));
                    case ('28')
                        signalNameArray(i+1) = cellstr('Bridge Amplifier Low');
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                        enabledSensors = bitor(enabledSensors,hex2dec('8000'));
                    otherwise
                        signalNameArray(i+1) = cellstr(hexSignalID);       % Default values for unrecognised data signal
                        signalDataTypeArray(i+1) = cellstr('u12');
                        nBytesDataPacket=nBytesDataPacket+2;
                end
            end
            
            thisShimmer.SignalNameArray = signalNameArray;
            thisShimmer.SignalDataTypeArray = signalDataTypeArray;
            thisShimmer.nBytesDataPacket = nBytesDataPacket;
            thisShimmer.EnabledSensors = enabledSensors;
            
        end  % function interpretdatapacketformat

        function newData = calculatetwoscomplement(thisShimmer,signedData,bitLength)
            % Calculates the two's complement of input signedData.
            newData=double(signedData);
            for i=1:numel(signedData)
                     if (bitLength==24)
                        if (signedData(i)>=bitshift(1,bitLength-1))
                            newData(i)=-(double( bitxor(signedData(i),(bitshift(1,bitLength)-1)))+1);
                        end
                     elseif (bitLength==16)
                        if (signedData(i)>=bitshift(1,bitLength-1))
                            newData(i)=-(double(bitcmp(uint16(signedData(i))))+1);
                        end
                    elseif (bitLength==8)
                      if (signedData(i)>=bitshift(1,bitLength-1))
                            newData(i)=-(double(bitcmp(uint8(signedData(i))))+1);
                      end
                    else
                        disp('Warning: calculatetwoscomplement - BitLength not supported for twocomplement method');
                    end
            end
            
        end %function calculatetwoscomplement

        function [timeStampData, signalName,signalFormat,signalUnit]=gettimestampdata(thisShimmer,dataMode,parsedData)
            % Gets Time Stamp data from input parsedData.
            if (thisShimmer.isStreaming)                     % Shimmer must be in a Streaming state
                
                if strcmp(dataMode,'a')
                    uncalibratedTimeStampData = parsedData(:,1);
                    calibratedTimeStampData=thisShimmer.calibratetimestampdata(uncalibratedTimeStampData);
                    timeStampData=[uncalibratedTimeStampData calibratedTimeStampData];
                    signalName{1}='Time Stamp';
                    signalFormat{1}='RAW';
                    signalUnit{1}='no units';
                    signalName{2}='Time Stamp';
                    signalFormat{2}='CAL';
                    signalUnit{2}='milliseconds';
                elseif strcmp(dataMode,'u')
                    uncalibratedTimeStampData = parsedData(:,1);
                    timeStampData=uncalibratedTimeStampData;
                    signalName{1}='Time Stamp';
                    signalFormat{1}='RAW';
                    signalUnit{1}='no units';
                elseif strcmp(dataMode,'c')
                    uncalibratedTimeStampData = parsedData(:,1);
                    calibratedTimeStampData=thisShimmer.calibratetimestampdata(uncalibratedTimeStampData);
                    timeStampData=calibratedTimeStampData;
                    signalName{1}='Time Stamp';
                    signalFormat{1}='CAL';
                    signalUnit{1}='milliseconds';
                else
                    disp('Warning: gettimestampdata - Wrong data mode specified');
                end
            else
                timeStampData = [];
                fprintf(strcat('Warning: gettimestampdata - Cannot get data as COM ',thisShimmer.name,' Shimmer is not Streaming'));
            end
        end

        function timeStampCalibratedData = calibratetimestampdata(thisShimmer,uncalibratedTimeStampData)
            % Calibration of Time Stamp data - calibrates input uncalibratedTimeStampData.
            contUncalibratedTimeStampData = [thisShimmer.LastUncalibratedLoopTimeStamp; uncalibratedTimeStampData + thisShimmer.nClockOverflows * 16777216]; % shift in LastUncalibratedLoopTimeStamp  and add clock overflow offsets of previous iterations
                
            for i=1:length(contUncalibratedTimeStampData)-1
                if (contUncalibratedTimeStampData(i+1) < contUncalibratedTimeStampData(i))
                    contUncalibratedTimeStampData(i+1:end) = contUncalibratedTimeStampData(i+1:end)+16777216; % add offset for each clock overflow within current iteration
                    thisShimmer.nClockOverflows = thisShimmer.nClockOverflows + 1;
                end
            end
            
            timeStampCalibratedData=contUncalibratedTimeStampData(2:end)/32768*1000; % omit last timestamp of previous iteration and convert to ms: C=(U/32768*1000) C=calibrated U=uncalibrated
            
            thisShimmer.LastUncalibratedLoopTimeStamp=contUncalibratedTimeStampData(end);
            
        end %function calibratetimestampdata
    end
end