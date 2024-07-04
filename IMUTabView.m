classdef IMUTabView < matlab.ui.componentcontainer.ComponentContainer
    %IMUTABVIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )
        % Line object used to visualize the model data.
        Line(1, 1) matlab.graphics.primitive.Line
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        %Components
        BTDeviceList
        BTScanButton
        DeviceConnect1 matlab.ui.componentcontainer.ComponentContainer
        DeviceConnect2 matlab.ui.componentcontainer.ComponentContainer
    end

    events ( NotifyAccess = private )
        % Event broadcast when view is interacted with
        BTScanButtonPushed

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
                "Connect", @obj.onConnect );
            obj.Listener(end+1) = listener( obj.DeviceConnect1, ... 
                "Disconnect", @obj.onDisconnect );
            obj.Listener(end+1) = listener( obj.DeviceConnect2, ... 
                "Connect", @obj.onConnect );
            obj.Listener(end+1) = listener( obj.DeviceConnect2, ... 
                "Disconnect", @obj.onDisconnect );

        end

        function SetBTScanButtonState( obj, state )
            if (strcmp(state, "Scanning"))
                obj.BTScanButton.Text = "Scanning...";
                obj.BTScanButton.Value = true;
                obj.BTScanButton.Enable = false;
            else
                obj.BTScanButton.Text = "Scan for Devices";
                obj.BTScanButton.Value = false;
                obj.BTScanButton.Enable = true;
            end

        end

        function setBTDeviceListData( obj, tableData )
            obj.BTDeviceList.Data = tableData;
        end
    end

    methods ( Access = protected )

        function setup( obj )
            %SETUP Initialize the view.

            gridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {22, 22, "1x", 35, 35}, ...
                "ColumnWidth", {"1x", "1x"} );

            % Create view components.
            btDeviceListLabel = uilabel("Parent", gridLayout, ...
                "Text", "Available Bluetooth Devices" );
            btDeviceListLabel.Layout.Row = 1;
            btDeviceListLabel.Layout.Column = 1;

            obj.BTScanButton = uibutton(gridLayout, "State", ...
                "Text", "Scan for Devices" );
            obj.BTScanButton.Layout.Row = 2;
            obj.BTScanButton.Layout.Column = 1;
            obj.BTScanButton.ValueChangedFcn = @obj.onBTScanButtonPushed;

            obj.BTDeviceList = uitable("Parent", gridLayout, ...
                "Enable", "off" );
            obj.BTDeviceList.Layout.Row = 3;
            obj.BTDeviceList.Layout.Column = 1;

            obj.DeviceConnect1 = DeviceConnect("Parent", gridLayout);
            obj.DeviceConnect1.Layout.Row = 4;
            obj.DeviceConnect1.Layout.Column = 1;
            
            obj.DeviceConnect2 = DeviceConnect("Parent", gridLayout);
            obj.DeviceConnect2.Layout.Row = 5;
            obj.DeviceConnect2.Layout.Column = 1;

        end

        function update( ~ )
            %UPDATE Update the view. This method is empty because there are
            %no public properties of the view.

        end

    end

    methods ( Access = private )

        function onBTScanButtonPushed( obj, ~, ~ )
            notify( obj, "BTScanButtonPushed" )
        end

        function onConnect(obj, ~, ~ )
            disp("Connect");
        end

        function onDisconnect(obj, ~, ~ )
            disp("Disconnect");
        end

    end

end