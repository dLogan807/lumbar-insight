classdef Model < handle
    %MODEL Application data model.
    
    properties
        % Application data.

        IMUDevices (2, 1) IMUInterface = []
        BluetoothDevices table

        Cameras (:, 1) Camera

        CurrentAngle double
        MaximumAngle double
        CorrectionAngle double
    end % properties ( SetAccess = private )
    
    events ( NotifyAccess = private )
        % Events broadcast when the model is altered.
        DeviceListUpdated

        ShimmerConnected
        ShimmerDisconnected
        ShimmerConfigured

        SessionStarted
        SessionEnded

        QuaternionGet

    end % events ( NotifyAccess = private )
    
    methods

        function set.BluetoothDevices ( obj, deviceList )
            obj.BluetoothDevices = deviceList;

            notify( obj, "DeviceListUpdated" )
        end

        function connectShimmer( shimmerName, obj )
            
            shimmerIndex = getShimmerIndexByName(shimmerName);
        
            obj.Shimmers(shimmerIndex).connect;

            notify( obj, "ShimmerConnected" )

        end % connectShimmer

        function disconnectShimmer( shimmerName, obj ) 

            shimmerIndex = getShimmerIndexByName(shimmerName);
        
            obj.Shimmers(shimmerIndex).disconnect;

            notify( obj, "ShimmerDisconnected" )

        end % disconnectShimmer

        function configureShimmer( shimmerName, obj ) 
            % Define settings for shimmer

            shimmerIndex = getShimmerIndexByName(shimmerName);
            shimmer = obj.Shimmers(shimmerIndex);
            


            notify( obj, "ShimmerConfigured" )

        end % configureShimmer

        function startSession( obj ) 
        
            obj.IMUDevices(1).start;
            obj.IMUDevices(2).start;

            notify( obj, "SessionStarted" )

        end % startSession

        function endSession( obj ) 
        
            obj.IMUDevices(1).stop;
            obj.IMUDevices(2).stop;

            notify( obj, "SessionEnded" )

        end % endSession

        function quaternion = getLastShimmerQuaternion( shimmerName, obj )
            % Get latest quaternion

            shimmerIndex = getShimmerIndexByName(shimmerName);
            shimmer = obj.Shimmers(shimmerIndex);


            notify( obj, "QuaternionGet" )
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