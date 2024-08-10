classdef BatteryStatus < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONNECT UI component for connecting to a device

    properties
        FontSize double = 12
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        RefreshButton matlab.ui.control.Button
        BatteryLabel matlab.ui.control.Label

        FontSet logical = false
        StatusTextChanged logical = false
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        RefreshBatteryStatusButtonPushed
    end

    methods
        function setButtonEnabled( obj, enabled )
            arguments
                obj 
                enabled logical 
            end

            if (enabled)
                obj.RefreshButton.Enable = "on";
            else
                obj.RefreshButton.Enable = "off";
            end
        end
        
        function setStatusText( obj, text )
            arguments
                obj 
                text string
            end

            obj.BatteryLabel.Text = text;
        end
    end

    methods (Access = protected)

        function setup( obj ) 
            % Create grid layout to manage building blocks 
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", { 30 }, ...
                "ColumnWidth", {"1x", "4x"} , ...
                "Padding", 0, ...
                "ColumnSpacing", 22 );

            % Create battery refresh button
            obj.RefreshButton = uibutton(obj.GridLayout, ...
                "Text", "Refresh", ...
                "Enable", "off");
            obj.RefreshButton.ButtonPushedFcn = @obj.refreshBatteryStatusButtonPushed;
            obj.RefreshButton.Layout.Column = 1;

            % Create status text label
            obj.BatteryLabel = uilabel(obj.GridLayout, ...
                "Text", "Device not connected. No battery information.");
            obj.BatteryLabel.Layout.Column = 2;
        end

        function update( obj )
            %Update component properties

            if (~obj.FontSet)
                set(findall(obj.GridLayout,'-property','FontSize'),'FontSize', obj.FontSize);
                obj.FontSet = true;
            end
        end
    end

    methods (Access = private)
        function refreshBatteryStatusButtonPushed( obj, ~, ~ )
            notify( obj, "RefreshBatteryStatusButtonPushed" )
        end
    end
end

