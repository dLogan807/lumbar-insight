classdef IMUTabView < matlab.ui.componentcontainer.ComponentContainer 
    %VIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )         
        % Line object used to visualize the model data.
        Line(1, 1) matlab.graphics.primitive.Line
        % Listener object used to respond dynamically to model events.
        Listener(:, 1) event.listener {mustBeScalarOrEmpty}

        %Components
        BTDeviceList
        BTScanButton
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

        end 

        function SetBTScanButtonState( obj, state)
            if (strcmp(state, "Scanning"))
                obj.BTScanButton.Text = "Scanning. This may take some time.";
                obj.BTScanButton.Enable = "off";
            else
                obj.BTScanButton.Text = "Scan for Devices";
                obj.BTScanButton.Enable = "on";
            end
            
        end

        function setBTDeviceListData( obj, tableData)
            obj.BTDeviceList.Data = tableData;
        end
    end 

    methods ( Access = protected ) 

        function setup( obj ) 
            %SETUP Initialize the view.

            gridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {22, 22, "1x", "1x"}, ...
                "ColumnWidth", {"1x", "1x"} );

            % Create view components. 
            btDeviceListLabel = uilabel("Parent", gridLayout, ...
                "Text", "Available Devices" );
            btDeviceListLabel.Layout.Row = 1;
            btDeviceListLabel.Layout.Column = 1;

            obj.BTScanButton = uibutton("Parent", gridLayout, ...
                "Text", "Scan for Devices" );
            obj.BTScanButton.Layout.Row = 2;
            obj.BTScanButton.Layout.Column = 1;
            set(obj.BTScanButton, 'ButtonPushedFcn', @obj.onBTScanButtonPushed);

            obj.BTDeviceList = uitable("Parent", gridLayout, ...
                "Enable", "off" );
            obj.BTDeviceList.Layout.Row = 3;
            obj.BTDeviceList.Layout.Column = 1;

        end

        function update( ~ ) 
            %UPDATE Update the view. This method is empty because there are 
            %no public properties of the view. 

        end

    end

    methods ( Access = private ) 

        function onBTScanButtonPushed( obj, ~, ~ )
            notify( obj, "BTScanButtonPushed" )
            disp("pushed")
        end

    end

end