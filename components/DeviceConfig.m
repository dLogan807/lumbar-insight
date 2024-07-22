classdef DeviceConfig < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONFIG UI component for configuring a device

    properties
        SamplingRate double = 60
        AvailableSamplingRates (1,:) double
        DeviceName string = ""
        DeviceType DeviceTypes
        State ConfigButtonStates = "Configure"

        FontSize double = 12
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        SamplingRateLabel matlab.ui.control.Label
        SamplingRateDropDown matlab.ui.control.DropDown
        DeviceConfigButton matlab.ui.control.Button 

        StateChanged logical = false
        FontSet logical = false;
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        Configure
    end

    methods (Access = protected)
        function setup( obj ) 
            % Create grid layout to manage building blocks 
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", { 22 }, ...
                "ColumnWidth", { "0.8x", "0.5x", "0.6x" } , ...
                "Padding", 0 );
        
            % Create sampling rate label
            obj.SamplingRateLabel = uilabel(obj.GridLayout, ...
                "Text", "Device not connected. Sampling Rate (Hz)" );
            obj.SamplingRateLabel.Layout.Column = 1;

            % Create drop down to select sampling rate
            obj.SamplingRateDropDown = uidropdown(obj.GridLayout, ...
                "Items", "Unavailable", ...
                "Editable", "off", ...
                "Enable", "off");
            obj.SamplingRateDropDown.ValueChangedFcn = @obj.samplingRateChanged;
            obj.SamplingRateDropDown.Layout.Column = 2;

            % Create button to configure
            obj.DeviceConfigButton = uibutton(obj.GridLayout, ...
                "Text", string(obj.State), ...
                "Enable", "off" );
            obj.DeviceConfigButton.ButtonPushedFcn = @obj.configureButtonPushed;
            obj.DeviceConfigButton.Layout.Column = 3;
        end

        function update( obj )
            %Update component properties
            if (~obj.FontSet)
                set(findall(obj.GridLayout,'-property','FontSize'),'FontSize', obj.FontSize);
                obj.FontSet = true;
            end

            if (obj.StateChanged)
                updateOverallState( obj );

                obj.StateChanged = false;

                drawnow;
            end
        end

        function updateOverallState( obj )
            if (obj.State == "Configure")
                obj.SamplingRateLabel.Text = obj.DeviceName + " Sampling Rate (Hz)";
                obj.SamplingRateDropDown.Enable = "on";
                obj.DeviceConfigButton.Text = "Configure";
                obj.SamplingRateDropDown.Items = string(obj.AvailableSamplingRates);
                obj.SamplingRate = str2double(obj.SamplingRateDropDown.Value);
                obj.DeviceConfigButton.Enable = "on";
            elseif (obj.State == "Configuring")
                obj.DeviceConfigButton.Enable = "off";
                obj.DeviceConfigButton.Text = "Configuring";
                obj.SamplingRateDropDown.Enable = "off";
            elseif ( obj.State == "Waiting" )
                obj.DeviceConfigButton.Text = "Waiting";
                obj.DeviceConfigButton.Enable = "off";
            elseif ( obj.State == "Disconnected" )
                obj.SamplingRateLabel.Text = "Device not connected. Sampling Rate (Hz)";
                obj.SamplingRateDropDown.Enable = "off";
                obj.SamplingRateDropDown.Items = "Unavailable";
                obj.DeviceConfigButton.Enable = "off";
                obj.DeviceConfigButton.Text = "Configure";
            end
        end
    end

    methods
        function set.FontSize( obj, fontSize )
            obj.FontSize = fontSize;
        end

        function set.State( obj, state )
            arguments
                obj
                state ConfigButtonStates
            end

            obj.State = state;
            obj.StateChanged = true;
        end

        function setDeviceInfo( obj, name, samplingRates )
            obj.DeviceName = name;
            obj.AvailableSamplingRates = samplingRates;

            obj.StateChanged = true;
        end
    end

    methods (Access = private)
        function configureButtonPushed( obj, ~, ~ )
            notify( obj, "Configure" );
        end

        function samplingRateChanged( obj, ~, ~)
            obj.SamplingRate = str2double(obj.SamplingRateDropDown.Value);
        end
    end
end

