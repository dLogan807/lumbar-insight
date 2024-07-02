classdef DeviceConnect < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONNECT Component for connecting to a device

    properties
        DeviceName string
        DeviceType DeviceType
        Connected logical
    end
    
    properties (Access = private,Transient,NonCopyable)
        Grid matlab.ui.container.GridLayout 
        DeviceNameEditField matlab.ui.control.EditField
        DeviceTypeDropDown matlab.ui.control.DropDown
        DeviceConnectButton matlab.ui.control.Button 
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        Connect
        Disconnect
    end

    methods
        function setup(comp) 
            % Create grid layout to manage building blocks 
            comp.Grid = uigridlayout( ...
                "Parent", comp, ...
                "RowHeight", { 22 }, ...
                "ColumnWidth", {"3x", "1x", "1x"} );
        
            % Create edit field for entering color value
            comp.DeviceNameEditField = uieditfield(comp.Grid); 
        
            % Create button to confirm color change
            comp.Button = uibutton(comp.Grid,'Text',char(9998), ... 
                'ButtonPushedFcn',@(o,e) comp.stateChanged()); 
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
        function stateChanged( comp )
            if (comp.Connected)
                notify(comp, 'Disconnect');
            else
                notify(comp,'Connect');
            end
        end
    end
end

