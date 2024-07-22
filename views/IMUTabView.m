classdef IMUTabView < matlab.ui.componentcontainer.ComponentContainer
    %IMUTABVIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        GridLayout

        FontSet logical = false
    end

    properties
        FontSize double = 12

        % Components
        BTDeviceList 
        BTScanButton
        
        DeviceConnect1 DeviceConnect
        DeviceConnect2 DeviceConnect

        Device1BatteryLabel matlab.ui.control.Label
        Device2BatteryLabel matlab.ui.control.Label
        BTDeviceListLabel matlab.ui.control.Label
        DeviceConnectLabel matlab.ui.control.Label
        BatteryInformationLabel matlab.ui.control.Label
        CalibrationLabel matlab.ui.control.Label

        CalibrateStandingPositionButton CalibrationButton
        CalibrateFullFlexionButton CalibrationButton
    end

    events ( NotifyAccess = private )
        % Event broadcast when view is interacted with
        BTScanButtonPushed

        Device1ConnectButtonPushed
        Device2ConnectButtonPushed
        Device1DisconnectButtonPushed
        Device2DisconnectButtonPushed

        CalibrateStandingPushed
        CalibrateFullFlexionPushed
    end % events ( NotifyAccess = private )

    methods

        function obj = IMUTabView( namedArgs )
            %VIEW View constructor.

            arguments
                namedArgs.?IMUTabView
            end % arguments

            % Do not create a default figure parent for the component, and
            % ensure that the component spans its parent. By default,
            % ComponentContainer objects are auto-parenting - that is, a
            % figure is created automatically if no parent argument is
            % specified.
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
                "RowHeight", {22, 22, 22, 22, 35, 35, 22, 35, 35, "1x", 22, 35, 35}, ...
                "ColumnWidth", {"1x", "1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 50 );

            % Create view components.
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
            obj.BTDeviceList.Layout.Row = [3, 10];
            obj.BTDeviceList.Layout.Column = 1;

            obj.DeviceConnectLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Connection", ...
                "FontWeight", "bold");
            obj.DeviceConnectLabel.Layout.Row = 11;
            obj.DeviceConnectLabel.Layout.Column = 1;

            obj.DeviceConnect1 = DeviceConnect("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.DeviceConnect1.Layout.Row = 12;
            obj.DeviceConnect1.Layout.Column = 1;
            
            obj.DeviceConnect2 = DeviceConnect("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize );
            obj.DeviceConnect2.Layout.Row = 13;
            obj.DeviceConnect2.Layout.Column = 1;

            obj.BatteryInformationLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Battery Information", ...
                "FontWeight", "bold");
            obj.BatteryInformationLabel.Layout.Row = 1;
            obj.BatteryInformationLabel.Layout.Column = 2;

            obj.Device1BatteryLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Device not connected. No battery information.");
            obj.Device1BatteryLabel.Layout.Row = 2;
            obj.Device1BatteryLabel.Layout.Column = 2;

            obj.Device2BatteryLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Device not connected. No battery information.");
            obj.Device2BatteryLabel.Layout.Row = 3;
            obj.Device2BatteryLabel.Layout.Column = 2;

            obj.CalibrationLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Calibration", "FontWeight", "bold");
            obj.CalibrationLabel.Layout.Row = 7;
            obj.CalibrationLabel.Layout.Column = 2;

            obj.CalibrateStandingPositionButton = CalibrationButton("Parent", obj.GridLayout, ...
                "ButtonLabel", "Calibrate Standing Position", ...
                "FontSize", obj.FontSize );
            obj.CalibrateStandingPositionButton.Layout.Row = 8;
            obj.CalibrateStandingPositionButton.Layout.Column = 2;

            obj.CalibrateFullFlexionButton = CalibrationButton("Parent", obj.GridLayout, ...
                "ButtonLabel", "Calibrate Full Flexion", ...
                "FontSize", obj.FontSize );
            obj.CalibrateFullFlexionButton.Layout.Row = 9;
            obj.CalibrateFullFlexionButton.Layout.Column = 2;
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

        function onCalibrateStandingPushed( obj, ~, ~ )
            notify( obj, "CalibrateStandingPushed");
        end

        function onCalibrateFullFlexionPushed( obj, ~, ~ )
            notify( obj, "CalibrateFullFlexionPushed");
        end
    end

end