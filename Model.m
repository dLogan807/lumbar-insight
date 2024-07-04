classdef Model < handle
    %MODEL Application data model.
    
    properties
        % Application data.

        IMUDevices (1, 2) IMUInterface = [ShimmerIMU("temp"), ShimmerIMU("temp")]
        BluetoothDevices table

        Cameras (1, :) Camera

        CurrentAngle double
        MaximumAngle double
        CorrectionAngle double
    end % properties ( SetAccess = private )
    
    events ( NotifyAccess = private )
        % Events broadcast when the model is altered.
        DeviceListUpdated

        DevicesConnectedChanged

        SessionStarted
        SessionEnded

        QuaternionUpdated

    end % events ( NotifyAccess = private )
    
    methods

        function set.BluetoothDevices ( obj, deviceList )
            % SET.BLUETOOTHDEVICES Set table of bluetooth devices, notify
            % controller

            obj.BluetoothDevices = deviceList;

            notify( obj, "DeviceListUpdated" )
        end

        function connectDevice( obj, deviceName, deviceType, deviceIndex )
            % CONNECTDEVICE Attempt device connection, notify controller

            connected = false;

            if (deviceType == DeviceTypes.Shimmer)
                obj.IMUDevices(deviceIndex) = ShimmerIMU(deviceName);
                connected = obj.IMUDevices(deviceIndex).connect;
            else
                disp("Device of type " + string(deviceType) + " is not implemented.");
            end

            notify( obj, "DevicesConnectedChanged" )

            if (connected)
                obj.IMUDevices(deviceIndex).configure;
            end

        end % connectDevice

        function disconnectDevice( obj, deviceIndex ) 
        
            obj.IMUDevices(deviceIndex).disconnect;

            notify( obj, "DevicesConnectedChanged" )

        end % disconnectDevice

        function startSession( obj ) 
        
            obj.IMUDevices(1).startSession;
            obj.IMUDevices(2).startSession;

            notify( obj, "SessionStarted" )

        end % startSession

        function endSession( obj ) 
        
            obj.IMUDevices(1).endSession;
            obj.IMUDevices(2).endSession;

            notify( obj, "SessionEnded" )

        end % endSession
        
    end % methods

end % classdef