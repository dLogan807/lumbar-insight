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

        DeviceConnected
        DeviceDisconnected
        DeviceConfigured

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

        function connectDevice( deviceName, obj )
            % CONNECTDEVICE Attempt device connection, notify controller 
            
            deviceIndex = getDeviceIndexByName(deviceName);
        
            connected = obj.IMUDevices(deviceIndex).connect;

            if (connected)
                notify( obj, "DeviceConnected" )
            else
                notify( obj, "DeviceConnectFailed" )
            end

        end % connectDevice

        function disconnectDevice( deviceName, obj ) 

            deviceIndex = getDeviceIndexByName(deviceName);
        
            disconnected = obj.IMUDevices(deviceIndex).disconnect;

            if (disconnected)
                notify( obj, "DeviceDisconnected" )
            else
                notify( obj, "DeviceDisconnectFailed" )
            end

        end % disconnectDevice

        function configureDevice( deviceName, obj ) 
            % Define settings for device

            deviceIndex = getDeviceIndexByName(deviceName);
            
            obj.IMUDevices(deviceIndex);

            notify( obj, "DeviceConfigured" )

        end % configureDevice

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

    methods (Access = private)

        function deviceIndex = getDeviceIndexByName( deviceName, obj )

            if (strcmp(obj.IMUDevices(1).Name, deviceName))
                deviceIndex = 1;
            elseif (strcmp(obj.IMUDevices(2).Name, deviceName))
                deviceIndex = 2;
            else
                deviceIndex = -1;
                warning("Unable to retrieve index of Device by name.");
            end

        end % deviceIndex

    end % private methods
    
end % classdef