classdef IMUTabController < handle
    %IMUTABCONTROLLER Provides an interactive control to generate new data.

    properties ( Access = private )
        % IMU View
        IMUTabView IMUTabView
        % Listener object used to respond dynamically to view events.
        Listener(:, 1) event.listener
    end % properties ( Access = private )
    
    properties ( GetAccess = public, SetAccess = private )
        % Application data model.
        Model(1, 1) Model
    end

    methods
        
        function obj = IMUTabController( model, imuTabView )
            % CONTROLLER Controller constructor.
            
            arguments
                model(1, 1) Model
                imuTabView IMUTabView
            end % arguments

            % Store the model.
            obj.Model = model;

            obj.IMUTabView = imuTabView;

            % Listen for changes to the view. 
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "BTScanButtonPushed", @obj.onBTScanButtonPushed );
            
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "Device1ConnectButtonPushed", @obj.onDevice1ConnectButtonPushed );
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "Device2ConnectButtonPushed", @obj.onDevice2ConnectButtonPushed );
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "Device1DisconnectButtonPushed", @obj.onDevice1DisconnectButtonPushed );
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "Device2DisconnectButtonPushed", @obj.onDevice2DisconnectButtonPushed );

            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "CalibrateStandingPushed", @obj.onCalibrateStandingPushed );
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "CalibrateFullFlexionPushed", @obj.onCalibrateFullFlexionPushed );

            % Listen for changes to the model data.
            obj.Listener(end+1) = listener( obj.Model, ... 
                "DeviceListUpdated", @obj.onDeviceListUpdated );
            obj.Listener(end+1) = listener( obj.Model, ... 
                "DevicesConnectedChanged", @obj.onDevicesChanged );
            obj.Listener(end+1) = listener( obj.Model, ... 
                "StandingAngleCalibrated", @obj.onStandingAngleCalibrated );
            obj.Listener(end+1) = listener( obj.Model, ... 
                "FullFlexionAngleCalibrated", @obj.onFullFlexionAngleCalibrated );
            
        end % constructor
        
    end % methods
    
    methods ( Access = protected )
        
        function setup( ~ )
            %SETUP Initialize the controller.
            
        end % setup
        
        function update( ~ )
            %UPDATE Update the controller. This method is empty because 
            %there are no public properties of the controller.
            
        end % update
        
    end % methods ( Access = protected )
    
    methods ( Access = private )
        function onBTScanButtonPushed( obj, ~, ~ ) 
            % ONBTSCANBUTTONPUSHED Listener callback, responding to the view event

            % Retrieve bluetooth devices and update the model.
            setBTScanButtonScanning( obj, true );

            allDevices = bluetoothlist("Timeout", 15);
            allDevices.Address = [];
            allDevices.Channel = [];
            allDevices = convertvars(allDevices,{'Name','Status'},'string');

            allDevices = statusHTMLToText(obj, allDevices);

            obj.Model.BluetoothDevices = allDevices;
        end

        function onDeviceListUpdated( obj, ~, ~ )
            obj.IMUTabView.BTDeviceList.Data = obj.Model.BluetoothDevices;
            setBTScanButtonScanning( obj, false );
        end

        function setBTScanButtonScanning( obj, isScanning )
            if (isScanning)
                obj.IMUTabView.BTScanButton.Text = "Scanning";
                obj.IMUTabView.BTScanButton.Value = true;
                obj.IMUTabView.BTScanButton.Enable = false;
            else
                obj.IMUTabView.BTScanButton.Text = "Scan for Devices";
                obj.IMUTabView.BTScanButton.Value = false;
                obj.IMUTabView.BTScanButton.Enable = true;
            end
        end

        function onDevice1ConnectButtonPushed( obj, ~, ~ )
            obj.Model.connectDevice(obj.IMUTabView.DeviceConnect1.DeviceName, obj.IMUTabView.DeviceConnect1.DeviceType, 1);
        end

        function onDevice2ConnectButtonPushed( obj, ~, ~ )
            obj.Model.connectDevice(obj.IMUTabView.DeviceConnect2.DeviceName, obj.IMUTabView.DeviceConnect2.DeviceType, 2);
        end

        function onDevice1DisconnectButtonPushed( obj, ~, ~ )
            obj.Model.disconnectDevice(1);
        end

        function onDevice2DisconnectButtonPushed( obj, ~, ~ )
            obj.Model.disconnectDevice(2);
        end

        function onDevicesChanged( obj, ~, ~ )
            % DEVICESCHANGED Update connect UI state
            obj.IMUTabView.DeviceConnect1.Connected = obj.Model.IMUDevices(1).IsConnected;
            obj.IMUTabView.DeviceConnect2.Connected = obj.Model.IMUDevices(2).IsConnected;

            if (obj.Model.IMUDevices(1).IsConnected)
                obj.IMUTabView.Device1BatteryLabel.Text = obj.Model.getBatteryInfo(1);
            else
                obj.IMUTabView.Device1BatteryLabel.Text = "Device not connected. No battery information.";
            end

            if (obj.Model.IMUDevices(2).IsConnected)
                obj.IMUTabView.Device2BatteryLabel.Text = obj.Model.getBatteryInfo(2);
            else
                obj.IMUTabView.Device2BatteryLabel.Text = "Device not connected. No battery information.";
            end

            obj.IMUTabView.CalibrateStandingPositionButton.Enable = obj.Model.twoIMUDevicesConnected;
            obj.IMUTabView.CalibrateFullFlexionButton.Enable = obj.Model.twoIMUDevicesConnected;
        end

        function onCalibrateStandingPushed( obj, ~, ~ )
            obj.Model.calibrateStandingAngle;
        end

        function onCalibrateFullFlexionPushed( obj, ~, ~ )
            obj.Model.calibrateFullFlexionAngle;
        end

        function onStandingAngleCalibrated( obj, ~, ~ )
            obj.IMUTabView.CalibrateStandingPositionButton.StatusText = obj.Model.StandingAngle + "°";
        end

        function onFullFlexionAngleCalibrated( obj, ~, ~ )
            obj.IMUTabView.CalibrateFullFlexionButton.StatusText = obj.Model.FullFlexionAngle + "°";
        end

        function formattedDevices = statusHTMLToText( ~, deviceTable )
            %STATUSHTMLTOTEXT Convert any HTML <a> elements to plaintext
            
            rows = height(deviceTable);
            for row = 1:rows
                currentRow = deviceTable.Status(row,:);

                startIndex = strfind(currentRow, ">");
                if (isempty(startIndex))
                    continue;
                end
                endIndex = strfind(currentRow, "</");

                deviceTable.Status(row,:) = extractBetween(currentRow, startIndex(1) + 1, endIndex(1) - 1);
            end

            formattedDevices = deviceTable;
        end
    end % methods ( Access = private )
    
end % classdef