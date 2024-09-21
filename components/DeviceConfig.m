classdef DeviceConfig < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONFIG UI component for configuring a device

    properties
        FontSize double = 12
    end

    properties (GetAccess = public, SetAccess = private)
        SamplingRateDropDown matlab.ui.control.DropDown
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        SamplingRateLabel matlab.ui.control.Label
        DeviceConfigButton matlab.ui.control.Button 

        FontSet logical = false;
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        Configure
    end

    methods (Access = protected)
        function setup( obj ) 
            %Create grid layout to manage building blocks 
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", { 30 }, ...
                "ColumnWidth", { "0.6x", "0.5x", "0.8x" } , ...
                "Padding", 0, ...
                "ColumnSpacing", 22 );

            %Create drop down to select sampling rate
            obj.SamplingRateDropDown = uidropdown(obj.GridLayout, ...
                "Items", "", ...
                "Value", "", ...
                "Placeholder", "Sampling Rate (Hz)", ...
                "Editable", "off", ...
                "Enable", "off");
            obj.SamplingRateDropDown.Layout.Column = 1;

            %Create button to configure
            obj.DeviceConfigButton = uibutton(obj.GridLayout, ...
                "Text", "Configure", ...
                "Enable", "off" );
            obj.DeviceConfigButton.ButtonPushedFcn = @obj.configureButtonPushed;
            obj.DeviceConfigButton.Layout.Column = 2;

            %Create sampling rate label
            obj.SamplingRateLabel = uilabel(obj.GridLayout, ...
                "Text", "Not configured." );
            obj.SamplingRateLabel.Layout.Column = 3;
        end

        function update( obj )
            %Update component properties
            if (~obj.FontSet)
                set(findall(obj.GridLayout,'-property','FontSize'),'FontSize', obj.FontSize);
                obj.FontSet = true;
            end
        end

    end

    methods
        function set.FontSize( obj, fontSize )
            arguments
                obj 
                fontSize double {mustBePositive, mustBeNonempty} 
            end

            obj.FontSize = fontSize;
        end

        function setDisconnected( obj )

            obj.SamplingRateLabel.Text = "Not configured.";
            obj.SamplingRateDropDown.Enable = "off";
            obj.SamplingRateDropDown.Items = "";
            obj.DeviceConfigButton.Enable = "off";
            obj.DeviceConfigButton.Text = "Configure";

            drawnow;
        end

        function setConfigurable( obj, name, availableSamplingRates)
            
            arguments
                obj 
                name string {mustBeTextScalar, mustBeNonempty}
                availableSamplingRates (1,:) double {mustBePositive, mustBeNonempty}
            end

            obj.SamplingRateLabel.Text = name + " not configured.";
            setConfigureable( obj, availableSamplingRates );

            drawnow;
        end

        function setConfiguring( obj )

            obj.DeviceConfigButton.Enable = "off";
            obj.DeviceConfigButton.Text = "Configuring";
            obj.SamplingRateDropDown.Enable = "off";
            
            drawnow;
        end

        function setConfigured( obj, name, availableSamplingRates, samplingRate)

            arguments
                obj
                name string {mustBeTextScalar, mustBeNonempty}
                availableSamplingRates (1,:) double {mustBePositive, mustBeNonempty}
                samplingRate double {mustBePositive, mustBeNonempty}
            end

            obj.SamplingRateLabel.Text = name + " set to " + samplingRate + "Hz.";
            setConfigureable( obj, availableSamplingRates );

            drawnow;
        end

    end

    methods (Access = private)
        function setConfigureable( obj, availableSamplingRates )
            
            arguments
                obj 
                availableSamplingRates (1,:) double {mustBePositive}
            end

            obj.SamplingRateDropDown.Enable = "on";
            obj.DeviceConfigButton.Text = "Configure";
            obj.SamplingRateDropDown.Items = string(availableSamplingRates);
            obj.DeviceConfigButton.Enable = "on";
        end

        function configureButtonPushed( obj, ~, ~ )
            notify( obj, "Configure" );
        end
    end
end

