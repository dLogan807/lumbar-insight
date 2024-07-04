classdef DeviceConnect < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONNECT UI component for connecting to a device

    properties
        DeviceName string
        DeviceType
        Connected logical
    end
    
    properties (Access = private, Transient, NonCopyable)
        Grid matlab.ui.container.GridLayout 
        DeviceNameEditField matlab.ui.control.EditField
        DeviceTypeDropDown matlab.ui.control.DropDown
        DeviceConnectButton matlab.ui.control.Button 
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        Connect
        Disconnect
    end

    methods (Access = protected)
        function setup( comp ) 
            % Create grid layout to manage building blocks 
            comp.Grid = uigridlayout( ...
                "Parent", comp, ...
                "RowHeight", { 22 }, ...
                "ColumnWidth", {"2x", "1x", "1x"} );
        
            % Create edit field for entering color value
            comp.DeviceNameEditField = uieditfield(comp.Grid, "Placeholder", "Device name");
            comp.DeviceNameEditField.Layout.Column = 1;

            comp.DeviceTypeDropDown = uidropdown(comp.Grid, "Items", string([enumeration("DeviceTypes")]));
            comp.DeviceTypeDropDown.Editable = "off";
            comp.DeviceTypeDropDown.Layout.Column = 2;
        
            % Create button to confirm color change
            comp.DeviceConnectButton = uibutton(comp.Grid, "Text", "Connect" );
            comp.DeviceConnectButton.ButtonPushedFcn = @comp.stateChanged;
            comp.DeviceConnectButton.Layout.Column = 3;
        end

        function update( comp )
            %Update component properties

            if (comp.Connected)
                comp.DeviceNameEditField.Editable = false;
                comp.DeviceConnectButton.Text = "Disconnect";
                comp.DeviceTypeDropDown.Editable = false;
            else
                comp.DeviceNameEditField.Editable = true;
                comp.DeviceConnectButton.Text = "Connect";
                comp.DeviceTypeDropDown.Editable = true;
            end
        end
    end

    methods (Access = private)
        function stateChanged( obj, ~, ~ )
            if (obj.Connected)
                notify(obj, 'Disconnect');
            else
                notify(obj,'Connect');
            end
        end
    end
end

