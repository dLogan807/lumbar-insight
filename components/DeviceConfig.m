classdef DeviceConfig < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONFIG UI component for configuring a device

    properties (SetAccess = private)
        SamplingRate double = 60
        AvailableSamplingRates (1,:) string = "Unavailable"
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
                "ColumnWidth", {"1x", "0.5x", "1x"} , ...
                "Padding", 0 );
        
            % Create sampling rate label
            obj.SamplingRateLabel = uilabel(obj.GridLayout, ...
                "Text", "Sampling Rate (Hz)" );
            obj.SamplingRateLabel.Layout.Column = 1;

            % Create drop down to select sampling rate
            obj.SamplingRateDropDown = uidropdown(obj.GridLayout, ...
                "Items", obj.AvailableSamplingRates, ...
                "Editable", "off", ...
                "Enable", "off");
            obj.SamplingRateDropDown.ValueChangedFcn = @obj.samplingRateChanged;
            obj.SamplingRateDropDown.Layout.Column = 2;

            % Create button to configure
            obj.DeviceConfigButton = uibutton(obj.GridLayout, ...
                "Text", string(obj.State) );
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
                updateConfigureButton( obj );
                updateSamplingRatesLabel( obj );

                drawnow;
            end
        end

        function updateConfigureButton( obj )
            obj.StateChanged = false;

            obj.DeviceConfigButton.Text = string(obj.State);

            if (obj.State == "Configure")
                obj.DeviceConfigButton.Enable = "on";
                obj.SamplingRateDropDown.Enable = "on";
            elseif (obj.State == "Configuring")
                obj.DeviceConfigButton.Enable = "off";
                obj.SamplingRateDropDown.Enable = "off";
            elseif ( obj.State == "Waiting" )
                obj.DeviceConfigButton.Enable = "off";
            end
        end

        function updateSamplingRatesLabel( obj )
            obj.SamplingRateDropDown.Items = obj.AvailableSamplingRates;
        end
    end

    methods
        function set.State( obj, state )
            arguments
                obj
                state ConfigureButtonStates
            end

            obj.State = state;
            obj.StateChanged = true;
        end

        function set.AvailableSamplingRates( obj, samplingRates )
            obj.AvailableSamplingRates = samplingRates;
        end
    end

    methods (Access = private)
        function configureButtonPushed( obj, ~, ~ )
            notify( obj, "Configure" );
        end

        function samplingRateChanged( obj, ~, ~)
            obj.SamplingRate = obj.SamplingRateDropDown.Value;
        end
    end
end

