classdef PollingRateField < matlab.ui.componentcontainer.ComponentContainer
    %UI component for overriding the polling rate to IMUs

    properties
        FontSize double = 12
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        PollingCheckbox matlab.ui.control.Checkbox
        RateEditField matlab.ui.control.EditField

        FontSet logical = false
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        PollingRateChanged
        PollingOverrideToggled
    end

    methods (Access = protected)

        function setup( obj ) 
            %Create grid layout to manage building blocks 
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", { 30 }, ...
                "ColumnWidth", {"1x", "1x"} , ...
                "Padding", 0, ...
                "ColumnSpacing", 22 );

            %Create checkbox
            obj.PollingCheckbox = uicheckbox( ...
                "Parent", obj.GridLayout, ...
                "Text", "Override IMU polling rate (Hz)", ...
                "ValueChangedFcn", @obj.pollingOverrideToggled );

            %Create numeric input field
            obj.RateEditField = uieditfield( ...
                obj.GridLayout, "numeric", ...
                "ValueDisplayFormat", "%.0f Hz", ...
                "Limits", [1 inf], ...
                "Value", 60, ...
                "ValueChangedFcn", @obj.pollingRateChanged );
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
        function pollingOverrideToggled( obj, ~, ~ )
            notify( obj, "PollingOverrideToggled" )
        end
        
        function pollingRateChanged( obj, ~, ~ )
            notify( obj, "PollingRateChanged" )
        end
    end
end

