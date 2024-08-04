classdef DeviceConnect < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONNECT UI component for connecting to a device

    properties
        DeviceName string
        DeviceType DeviceTypes
        State ConnectButtonStates = "Connect"

        FontSize double = 12
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        DeviceNameEditField matlab.ui.control.EditField
        DeviceTypeDropDown matlab.ui.control.DropDown
        DeviceConnectButton matlab.ui.control.Button 

        StateChanged logical = false
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
            obj.DeviceConnectButton = uibutton(obj.GridLayout, "Text", string(obj.State) );
            obj.DeviceConnectButton.ButtonPushedFcn = @obj.connectButtonPushed;
            obj.DeviceConnectButton.Layout.Column = 3;
        end

        function update( obj )
            %Update component properties
            if (~obj.FontSet)
                set(findall(obj.GridLayout,'-property','FontSize'),'FontSize', obj.FontSize);
                obj.FontSet = true;
            end

            if (obj.StateChanged)
                updateConnectButton( obj );
            end
        end

        function updateConnectButton( obj )
            obj.StateChanged = false;

            obj.DeviceConnectButton.Text = string(obj.State);

            if (obj.State == "Connect")
                obj.DeviceConnectButton.Enable = "on";

                obj.DeviceNameEditField.Enable = "on";
                obj.DeviceTypeDropDown.Enable = "on";
            elseif (obj.State == "Connecting")
                obj.DeviceConnectButton.Enable = "off";
                
                obj.DeviceNameEditField.Enable = "off";
                obj.DeviceTypeDropDown.Enable = "off";
            elseif (obj.State == "Disconnect")
                obj.DeviceConnectButton.Enable = "on";
            end
        end
    end

    methods
        function set.State( obj, state )
            arguments
                obj
                state ConnectButtonStates
            end

            obj.State = state;
            obj.StateChanged = true;

            drawnow;
        end
    end

    methods (Access = private)
        function connectButtonPushed( obj, ~, ~ )
            if (obj.State == "Connect")
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

