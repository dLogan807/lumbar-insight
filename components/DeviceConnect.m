classdef DeviceConnect < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONNECT UI component for connecting to a device

    properties
        DeviceName string
        DeviceType DeviceTypes
        Connected logical

        FontSize double = 12
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        DeviceNameEditField matlab.ui.control.EditField
        DeviceTypeDropDown matlab.ui.control.DropDown
        DeviceConnectButton matlab.ui.control.Button 
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        Connect
        Disconnect
    end

    methods (Access = protected)
        function setup( obj ) 
            % Create grid layout to manage building blocks 
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", { 22 }, ...
                "ColumnWidth", {"2x", "1x", "1x"} , ...
                "Padding", 0 );
        
            % Create edit field for entering device name
            obj.DeviceNameEditField = uieditfield(obj.GridLayout, "Placeholder", "Device name");
            obj.DeviceNameEditField.ValueChangedFcn = @obj.deviceNameChanged;
            obj.DeviceNameEditField.Layout.Column = 1;

            % Create drop down to select device type
            obj.DeviceTypeDropDown = uidropdown(obj.GridLayout, "Items", string([enumeration("DeviceTypes")]));
            obj.DeviceTypeDropDown.Editable = "off";
            obj.DeviceTypeDropDown.ValueChangedFcn = @obj.deviceTypeChanged;
            obj.DeviceTypeDropDown.Layout.Column = 2;

            obj.DeviceType = DeviceTypes.Shimmer;

            % Create button to connect
            obj.DeviceConnectButton = uibutton(obj.GridLayout, "Text", "Connect" );
            obj.DeviceConnectButton.ButtonPushedFcn = @obj.stateChanged;
            obj.DeviceConnectButton.Layout.Column = 3;
        end

        function update( obj )
            %Update component properties

            obj.DeviceConnectButton.Enable = "on";

            if (obj.Connected)
                obj.DeviceNameEditField.Enable = "off";
                obj.DeviceConnectButton.Text = "Disconnect";
                obj.DeviceTypeDropDown.Enable = "off";
            else
                obj.DeviceNameEditField.Enable = "on";
                obj.DeviceConnectButton.Text = "Connect";
                obj.DeviceTypeDropDown.Enable = "on";
            end

            set(findall(obj.GridLayout,'-property','FontSize'),'FontSize', obj.FontSize);
        end
    end

    methods (Access = private)
        function stateChanged( obj, ~, ~ )
            if (obj.Connected)
                notify(obj, 'Disconnect' );
            else
                obj.DeviceConnectButton.Text = "Connecting";
                obj.DeviceConnectButton.Enable = "off";
                notify(obj,'Connect' );
            end
        end

        function deviceTypeChanged( obj, ~, ~)
            obj.DeviceType = obj.DeviceTypeDropDown.Value;
        end

        function deviceNameChanged( obj, ~, ~)
            obj.DeviceName = obj.DeviceNameEditField.Value;
        end
    end
end

