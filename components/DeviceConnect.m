classdef DeviceConnect < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONNECT UI component for connecting to a device

    properties
        DeviceName string
        DeviceType DeviceTypes

        FontSize double = 12
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        DeviceNameEditField matlab.ui.control.EditField
        DeviceTypeDropDown matlab.ui.control.DropDown
        DeviceConnectButton matlab.ui.control.Button 

        FontSet logical = false;
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
                "RowHeight", { 30 }, ...
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
            obj.DeviceConnectButton.ButtonPushedFcn = @obj.connectButtonPushed;
            obj.DeviceConnectButton.Layout.Column = 3;
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
        function setConnectButtonState( obj, state)
            %Set the button's appearance based on enum

            arguments
                obj
                state ConnectButtonStates {mustBeNonempty}
            end

            obj.DeviceConnectButton.Text = string(state);
            
            if (state == "Connect")
                obj.DeviceConnectButton.Enable = "on";
                obj.DeviceNameEditField.Enable = "on";
                obj.DeviceTypeDropDown.Enable = "on";
            elseif (state == "Connecting")
                obj.DeviceConnectButton.Enable = "off";
                
                obj.DeviceNameEditField.Enable = "off";
                obj.DeviceTypeDropDown.Enable = "off";
            elseif (state == "Disconnect")
                obj.DeviceConnectButton.Enable = "on";
            end

            drawnow
        end
    end

    methods (Access = private)
        function connectButtonPushed( obj, ~, ~ )
            if (obj.DeviceConnectButton.Text == "Connect")
                notify(obj,'Connect' );
            else
                notify( obj, "Disconnect" );
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

