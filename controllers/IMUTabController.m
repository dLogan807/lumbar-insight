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
                "Device1ConfigureButtonPushed", @obj.onDevice1ConfigureButtonPushed );
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "Device2ConfigureButtonPushed", @obj.onDevice2ConfigureButtonPushed );

            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "CalibrateStandingPushed", @obj.onCalibrateStandingPushed );
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "CalibrateFullFlexionPushed", @obj.onCalibrateFullFlexionPushed );

            % Listen for changes to the model.
            obj.Listener(end+1) = listener( obj.Model, ... 
                "OperationStarted", @obj.onOperationStarted );
            obj.Listener(end+1) = listener( obj.Model, ... 
                "OperationCompleted", @obj.onOperationCompleted );
            
            obj.Listener(end+1) = listener( obj.Model, ... 
                "DevicesConnectedChanged", @obj.onDevicesChanged );

            obj.Listener(end+1) = listener( obj.Model, ... 
                "DevicesConfiguredChanged", @obj.onDevicesConfiguredChanged );

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

            obj.IMUTabView.BTDeviceList.Data = allDevices;
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

            if(obj.Model.OperationInProgress)
                return
            end

            obj.IMUTabView.DeviceConnect1.State = "Connecting";
            if (obj.IMUTabView.DeviceConnect2.State == "Connect")
                obj.IMUTabView.DeviceConnect2.State = "Waiting";
            end

            obj.Model.connectDevice(obj.IMUTabView.DeviceConnect1.DeviceName, obj.IMUTabView.DeviceConnect1.DeviceType, 1);
        end

        function onDevice2ConnectButtonPushed( obj, ~, ~ )

            if(obj.Model.OperationInProgress)
                return
            end

            obj.IMUTabView.DeviceConnect2.State = "Connecting";
            if (obj.IMUTabView.DeviceConnect1.State == "Connect")
                obj.IMUTabView.DeviceConnect1.State = "Waiting";
            end

            obj.Model.connectDevice(obj.IMUTabView.DeviceConnect2.DeviceName, obj.IMUTabView.DeviceConnect2.DeviceType, 2);
        end

        function onDevice1DisconnectButtonPushed( obj, ~, ~ )
            if(obj.Model.OperationInProgress)
                return
            end

            obj.Model.disconnectDevice(1);
        end

        function onDevice2DisconnectButtonPushed( obj, ~, ~ )
            if(obj.Model.OperationInProgress)
                return
            end

            obj.Model.disconnectDevice(2);
        end

        function onOperationStarted( obj, ~, ~ )
            obj.IMUTabView.OperationLabel.Text = "Operation in progress. Please wait.";
            drawnow;
        end

        function onOperationCompleted( obj, ~, ~ )
            %ONOPERATIONCOMPLETED Prompt the user of the next configuration
            %step

            obj.IMUTabView.OperationLabel.Text = "No operations are in progress.";
            statusLabel = obj.IMUTabView.StatusLabel;

            if (~obj.Model.bothIMUDevicesConnected)
                statusLabel.Text = "Please connect two IMUs.";
            elseif (~obj.Model.IMUDevices(1).IsConfigured)
                statusLabel.Text = "Please configure " + obj.Model.IMUDevices(1).Name + ".";
            elseif (~obj.Model.IMUDevices(2).IsConfigured)
                statusLabel.Text = "Please configure " + obj.Model.IMUDevices(2).Name + ".";
            elseif (isempty(obj.Model.StandingAngle))
                statusLabel.Text = "Please calibrate the subject's angle whilst standing.";
            elseif (isempty(obj.Model.FullFlexionAngle))
                statusLabel.Text = "Please calibrate the subject's angle whilst at full flexion.";
            elseif (obj.Model.IMUDevices(1).SamplingRate ~= obj.Model.IMUDevices(2).SamplingRate)
                statusLabel.Text = "Setup completed. Note the lowest sampling rate will be used! A session can be started.";
            else
                statusLabel.Text = "Setup completed. A session can be started.";
            end

            drawnow;
        end

        function onDevicesChanged( obj, ~, ~ )
            % DEVICESCHANGED Update UI on device connect or disconnect
            
            setDeviceConnectState( obj, obj.Model.IMUDevices(1), obj.IMUTabView.DeviceConnect1 );
            setDeviceConnectState( obj, obj.Model.IMUDevices(2), obj.IMUTabView.DeviceConnect2 );

            obj.IMUTabView.Device1BatteryLabel.Text = obj.Model.getBatteryInfo(1);
            obj.IMUTabView.Device2BatteryLabel.Text = obj.Model.getBatteryInfo(2);

            setDeviceConfigState( obj, obj.Model.IMUDevices(1), obj.IMUTabView.DeviceConfig1 );
            setDeviceConfigState( obj, obj.Model.IMUDevices(2), obj.IMUTabView.DeviceConfig2 );

            updateCalibrationEnabled( obj );
        end

        function setDeviceConnectState( ~, imuDevice, deviceConnect )
            arguments
                ~
                imuDevice IMUInterface
                deviceConnect DeviceConnect
            end

            if (imuDevice.IsConnected)
                deviceConnect.State = "Disconnect";
            else
                deviceConnect.State = "Connect";
            end
        end

        function onDevicesConfiguredChanged( obj, ~, ~ )
            setDeviceConfigState( obj, obj.Model.IMUDevices(1), obj.IMUTabView.DeviceConfig1 );
            setDeviceConfigState( obj, obj.Model.IMUDevices(2), obj.IMUTabView.DeviceConfig2 );

            updateCalibrationEnabled( obj );
        end

        function updateCalibrationEnabled( obj )
            if (obj.Model.bothIMUDevicesConfigured)
                obj.IMUTabView.CalibrateStandingPositionButton.Enable = true;
                obj.IMUTabView.CalibrateFullFlexionButton.Enable = true;

                obj.Model.startStreamingBoth;
            else
                obj.IMUTabView.CalibrateStandingPositionButton.Enable = false;
                obj.IMUTabView.CalibrateFullFlexionButton.Enable = false;

                obj.IMUTabView.CalibrateStandingPositionButton.StatusText = "Not Calibrated.";
                obj.IMUTabView.CalibrateFullFlexionButton.StatusText = "Not Calibrated.";

                obj.Model.stopStreamingBoth;
            end
        end

        function setDeviceConfigState( ~, imuDevice, deviceConfig )
            arguments
                ~
                imuDevice IMUInterface
                deviceConfig DeviceConfig
            end

            if (imuDevice.IsConfigured)
                deviceConfig.State = "Configured";
            elseif (imuDevice.IsConnected)
                deviceConfig.setDeviceInfo(imuDevice.Name, imuDevice.SamplingRates);
                deviceConfig.State = "Configure";
            else
                deviceConfig.State = "Disconnected";
            end
        end

        function onDevice1ConfigureButtonPushed( obj, ~, ~ )
            if(obj.Model.OperationInProgress)
                return
            end

            obj.IMUTabView.DeviceConfig1.State = "Configuring";
            obj.IMUTabView.DeviceConfig2.State = "Waiting";

            samplingRate = obj.IMUTabView.DeviceConfig1.SamplingRate;
            obj.Model.configure(1, samplingRate);
        end

        function onDevice2ConfigureButtonPushed( obj, ~, ~ )
            if(obj.Model.OperationInProgress)
                return
            end
            
            obj.IMUTabView.DeviceConfig2.State = "Configuring";
            obj.IMUTabView.DeviceConfig1.State = "Waiting";

            samplingRate = obj.IMUTabView.DeviceConfig2.SamplingRate;
            obj.Model.configure(2, samplingRate);
        end

        function onCalibrateStandingPushed( obj, ~, ~ )
            obj.Model.calibrateAngle( "s" );
        end

        function onCalibrateFullFlexionPushed( obj, ~, ~ )
            obj.Model.calibrateAngle( "f" );
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