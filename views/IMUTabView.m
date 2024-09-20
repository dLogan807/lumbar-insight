classdef IMUTabView < matlab.ui.componentcontainer.ComponentContainer
    %IMUTABVIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        FontSet logical = false
    end

    properties
        FontSize double = 12

        % Components
        GridLayout matlab.ui.container.GridLayout

        BTDeviceList matlab.ui.control.Table
        BTScanButton matlab.ui.control.StateButton
        
        DeviceConnect1 DeviceConnect
        DeviceConnect2 DeviceConnect

        Device1BatteryStatus BatteryStatus
        Device2BatteryStatus BatteryStatus

        BTDeviceListLabel matlab.ui.control.Label
        DeviceConnectLabel matlab.ui.control.Label
        BatteryInformationLabel matlab.ui.control.Label

        ConfigurationLabel matlab.ui.control.Label
        DeviceConfig1 DeviceConfig
        DeviceConfig2 DeviceConfig
        PollingRateOverride PollingRateField

        CalibrationLabel matlab.ui.control.Label
        CalibrateStandingPositionButton CalibrationButton
        CalibrateFullFlexionButton CalibrationButton

        StatusLabel matlab.ui.control.Label
        OperationLabel matlab.ui.control.Label
    end

    events ( NotifyAccess = private )
        % Event broadcast when view is interacted with
        BTScanButtonPushed

        Device1ConnectButtonPushed
        Device2ConnectButtonPushed
        Device1DisconnectButtonPushed
        Device2DisconnectButtonPushed

        Device1BatteryRefreshButtonPushed
        Device2BatteryRefreshButtonPushed

        Device1ConfigureButtonPushed
        Device2ConfigureButtonPushed

        PollingRateChanged
        PollingOverrideEnabled
        PollingOverrideDisabled

        CalibrateStandingPushed
        CalibrateFullFlexionPushed
    end % events ( NotifyAccess = private )

    methods

        function obj = IMUTabView( namedArgs )
            % View constructor.

            arguments
                namedArgs.?IMUTabView
            end % arguments

            % Do not create a default figure parent for the component, and
            % ensure that the component spans its parent.
            obj@matlab.ui.componentcontainer.ComponentContainer( ...
                "Parent", [], ...
                "Units", "normalized", ...
                "Position", [0, 0, 1, 1] )

            % Set any user-specified properties.
            set( obj, namedArgs )

            % Listen for changes in components
            obj.Listener(end+1) = listener( obj.DeviceConnect1, ... 
                "Connect", @obj.onDevice1Connect );
            obj.Listener(end+1) = listener( obj.DeviceConnect1, ... 
                "Disconnect", @obj.onDevice1Disconnect );
            obj.Listener(end+1) = listener( obj.DeviceConnect2, ... 
                "Connect", @obj.onDevice2Connect );
            obj.Listener(end+1) = listener( obj.DeviceConnect2, ... 
                "Disconnect", @obj.onDevice2Disconnect );

            obj.Listener(end+1) = listener( obj.Device1BatteryStatus, ...
                "RefreshBatteryStatusButtonPushed", @obj.onRefreshBatteryStatus1ButtonPushed );
            obj.Listener(end+1) = listener( obj.Device2BatteryStatus, ...
                "RefreshBatteryStatusButtonPushed", @obj.onRefreshBatteryStatus2ButtonPushed );

            obj.Listener(end+1) = listener( obj.DeviceConfig1, ...
                "Configure", @obj.onDevice1Configure );
            obj.Listener(end+1) = listener( obj.DeviceConfig2, ...
                "Configure", @obj.onDevice2Configure );

            obj.Listener(end+1) = listener( obj.PollingRateOverride, ...
                "PollingRateChanged", @obj.onPollingRateChanged );
            obj.Listener(end+1) = listener( obj.PollingRateOverride, ...
                "PollingOverrideEnabled", @obj.onPollingOverrideEnabled );
            obj.Listener(end+1) = listener( obj.PollingRateOverride, ...
                "PollingOverrideDisabled", @obj.onPollingOverrideDisabled );

            obj.Listener(end+1) = listener( obj.CalibrateStandingPositionButton, ... 
                "CalibrateButtonPushed", @obj.onCalibrateStandingPushed );
            obj.Listener(end+1) = listener( obj.CalibrateFullFlexionButton, ... 
                "CalibrateButtonPushed", @obj.onCalibrateFullFlexionPushed );
        end
    end

    methods ( Access = protected )

        function setup( obj )
            %SETUP Initialize the view.

            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {22, 30, 30, 30, 30, 30, 30, 22, 30, 30, "1x", 22, 30, 30}, ...
                "ColumnWidth", {"1x", "1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 100 );

            % Create view components

            % Bluetooth scanning components
            obj.BTDeviceListLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Available Bluetooth Devices", ...
                "FontWeight", "bold");
            obj.BTDeviceListLabel.Layout.Row = 1;
            obj.BTDeviceListLabel.Layout.Column = 1;

            obj.BTScanButton = uibutton(obj.GridLayout, "State", ...
                "Text", "Scan for Devices" );
            obj.BTScanButton.Layout.Row = 2;
            obj.BTScanButton.Layout.Column = 1;
            obj.BTScanButton.ValueChangedFcn = @obj.onBTScanButtonPushed;

            obj.BTDeviceList = uitable("Parent", obj.GridLayout, ...
                "Enable", "off" );
            obj.BTDeviceList.Layout.Row = [3, 11];
            obj.BTDeviceList.Layout.Column = 1;

            % Connection components
            obj.DeviceConnectLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Connection", ...
                "FontWeight", "bold");
            obj.DeviceConnectLabel.Layout.Row = 12;
            obj.DeviceConnectLabel.Layout.Column = 1;

            obj.DeviceConnect1 = DeviceConnect("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.DeviceConnect1.Layout.Row = 13;
            obj.DeviceConnect1.Layout.Column = 1;
            
            obj.DeviceConnect2 = DeviceConnect("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.DeviceConnect2.Layout.Row = 14;
            obj.DeviceConnect2.Layout.Column = 1;

            % Battery components
            obj.BatteryInformationLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Battery Information", ...
                "FontWeight", "bold");
            obj.BatteryInformationLabel.Layout.Row = 1;
            obj.BatteryInformationLabel.Layout.Column = 2;

            obj.Device1BatteryStatus = BatteryStatus("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.Device1BatteryStatus.Layout.Row = 2;
            obj.Device1BatteryStatus.Layout.Column = 2;

            obj.Device2BatteryStatus = BatteryStatus("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.Device2BatteryStatus.Layout.Row = 3;
            obj.Device2BatteryStatus.Layout.Column = 2;

            % Configuration components
            obj.ConfigurationLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Configuration (Hz)", "FontWeight", "bold");
            obj.ConfigurationLabel.Layout.Row = 4;
            obj.ConfigurationLabel.Layout.Column = 2;

            obj.DeviceConfig1 = DeviceConfig("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.DeviceConfig1.Layout.Row = 5;
            obj.DeviceConfig1.Layout.Column = 2;

            obj.DeviceConfig2 = DeviceConfig("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.DeviceConfig2.Layout.Row = 6;
            obj.DeviceConfig2.Layout.Column = 2;

            % Polling rate override component
            obj.PollingRateOverride = PollingRateField("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.PollingRateOverride.Layout.Row = 7;
            obj.PollingRateOverride.Layout.Column = 2;

            % Calibration components
            obj.CalibrationLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Calibration", ...
                "FontWeight", "bold");
            obj.CalibrationLabel.Layout.Row = 8;
            obj.CalibrationLabel.Layout.Column = 2;

            obj.CalibrateStandingPositionButton = CalibrationButton("Parent", obj.GridLayout, ...
                "ButtonLabel", "Calibrate Standing Offset", ...
                "FontSize", obj.FontSize );
            obj.CalibrateStandingPositionButton.Layout.Row = 9;
            obj.CalibrateStandingPositionButton.Layout.Column = 2;

            obj.CalibrateFullFlexionButton = CalibrationButton("Parent", obj.GridLayout, ...
                "ButtonLabel", "Calibrate Full Flexion", ...
                "FontSize", obj.FontSize );
            obj.CalibrateFullFlexionButton.Layout.Row = 10;
            obj.CalibrateFullFlexionButton.Layout.Column = 2;

            % Configuration status components
            AppStatusHeadingLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Configuration Status", ...
                "FontWeight", "bold" );
            AppStatusHeadingLabel.Layout.Row = 12;
            AppStatusHeadingLabel.Layout.Column = 2;

            obj.StatusLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Please two connect IMUs." );
            obj.StatusLabel.Layout.Row = 13;
            obj.StatusLabel.Layout.Column = 2;

            obj.OperationLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "No operations are in progress." );
            obj.OperationLabel.Layout.Row = 14;
            obj.OperationLabel.Layout.Column = 2;
        end

        function update( obj )
            if (~obj.FontSet)
                set(findall(obj.GridLayout,'-property','FontSize'),'FontSize', obj.FontSize);
                obj.FontSet = true;
            end
        end

    end

    methods ( Access = private )

        function onBTScanButtonPushed( obj, ~, ~ )
            notify( obj, "BTScanButtonPushed" )
        end

        function onDevice1Connect( obj, ~, ~ )
            notify( obj, "Device1ConnectButtonPushed")
        end

        function onDevice1Disconnect (obj, ~, ~ )
            notify( obj, "Device1DisconnectButtonPushed");
        end

        function onDevice2Connect( obj, ~, ~ )
            notify( obj, "Device2ConnectButtonPushed")
        end

        function onDevice2Disconnect( obj, ~, ~ )
            notify( obj, "Device2DisconnectButtonPushed");
        end

        function onRefreshBatteryStatus1ButtonPushed( obj, ~, ~ )
            notify( obj, "Device1BatteryRefreshButtonPushed");
        end

        function onRefreshBatteryStatus2ButtonPushed( obj, ~, ~ )
            notify( obj, "Device2BatteryRefreshButtonPushed");
        end

        function onDevice1Configure( obj, ~, ~ )
            notify( obj, "Device1ConfigureButtonPushed");
        end

        function onDevice2Configure( obj, ~, ~ )
            notify( obj, "Device2ConfigureButtonPushed");
        end

        function onPollingRateChanged( obj, ~, ~ )
            notify( obj, "PollingRateChanged" );
        end

        function onPollingOverrideEnabled( obj, ~, ~ )
            notify( obj, "PollingOverrideEnabled" );
        end

        function onPollingOverrideDisabled( obj, ~, ~ )
            notify( obj, "PollingOverrideDisabled" );
        end

        function onCalibrateStandingPushed( obj, ~, ~ )
            notify( obj, "CalibrateStandingPushed");
        end

        function onCalibrateFullFlexionPushed( obj, ~, ~ )
            notify( obj, "CalibrateFullFlexionPushed");
        end
    end

end