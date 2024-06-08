classdef Model < handle
    %MODEL Application data model.
    
    properties ( SetAccess = private )
        % Application data.

        Shimmers (1,2) ShimmerHandleClass

        Cameras (1,:) Camera


    end % properties ( SetAccess = private )
    
    events ( NotifyAccess = private )
        % Event broadcast when the data is changed.
        ConnectedShimmer
        DisconnectedShimmer
        ConfiguredShimmer

        SessionStarted
        SessionEnded

    end % events ( NotifyAccess = private )
    
    methods

        function connectShimmer( shimmerName, obj )
            
            shimmerIndex = getShimmerIndexByName(shimmerName);
        
            obj.Shimmers(shimmerIndex).connect;

            notify( obj, "ConnectedShimmer" )

        end % connectShimmer

        function disconnectShimmer( shimmerName, obj ) 

            shimmerIndex = getShimmerIndexByName(shimmerName);
        
            obj.Shimmers(shimmerIndex).disconnect;

            notify( obj, "DisconnectedShimmer" )

        end % disconnectShimmer

        function configureShimmer( shimmerName, obj ) 
            % Define settings for shimmer

            shimmerIndex = getShimmerIndexByName(shimmerName);
            shimmer = obj.Shimmers(shimmerIndex);
            
            SensorMacros = SetEnabledSensorsMacrosClass;                           % assign user friendly macros for setenabledsensors
    
            shimmer.setsamplingrate(51.2);                                         % Set the shimmer sampling rate to 51.2Hz
    	    shimmer.setinternalboard('9DOF');                                      % Set the shimmer internal daughter board to '9DOF'
            shimmer.disableallsensors;                                             % disable all sensors
            shimmer.setenabledsensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,...   % Enable the gyroscope, magnetometer and accelerometer.
            SensorMacros.ACCEL,1);                                                  
            shimmer.setaccelrange(0);                                              % Set the accelerometer range to 0 (+/- 1.5g for Shimmer2/2r, +/- 2.0g for Shimmer3)
            shimmer.setorientation3D(1);                                           % Enable orientation3D
            shimmer.setgyroinusecalibration(1);                                    % Enable gyro in-use calibration

            notify( obj, "ConfiguredShimmer" )

        end % configureShimmer

        function startSession( obj ) 
        
            obj.Shimmers(1).start;
            obj.Shimmers(2).start;

            notify( obj, "SessionStarted" )

        end % startSession

        function endSession( obj ) 
        
            obj.Shimmers(1).stop;
            obj.Shimmers(2).stop;

            notify( obj, "SessionEnded" )

        end % endSession

        function quaternion = getLastShimmerQuaternion( shimmerName, obj )
            % Get latest quaternion

            shimmerIndex = getShimmerIndexByName(shimmerName);
            shimmer = obj.Shimmers(shimmerIndex);

            [shimmerData,shimmerSignalNameArray,~,~] = shimmer.getdata('c');

            shimmerQuaternionChannels(1) = find(ismember(shimmerSignalNameArray, 'Quaternion 0'));                  % Find Quaternion signal indices.
            shimmerQuaternionChannels(2) = find(ismember(shimmerSignalNameArray, 'Quaternion 1'));
            shimmerQuaternionChannels(3) = find(ismember(shimmerSignalNameArray, 'Quaternion 2'));
            shimmerQuaternionChannels(4) = find(ismember(shimmerSignalNameArray, 'Quaternion 3'));

            quaternion = shimmerData(end, shimmerQuaternionChannels);

        end % getLastShimmerQuaternion
        
    end % methods

    methods (Access = private)

        function shimmerIndex = getShimmerIndexByName( shimmerName, obj )

            if (strcmp(obj.Shimmers(1).name, shimmerName))
                shimmerIndex = 1;
            elseif (strcmp(obj.Shimmers(2).name, shimmerName))
                shimmerIndex = 2;
            else
                shimmerIndex = -1;
                warning("Unable to retrieve index of Shimmer by name.");
            end

        end % shimmerIndex

    end % private methods
    
end % classdef