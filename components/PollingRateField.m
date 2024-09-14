classdef PollingRateField < matlab.ui.componentcontainer.ComponentContainer
    %UI component for overriding the polling rate to IMUs

    properties
        FontSize double = 12

        PollingRate double = 60
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        PollingCheckbox matlab.ui.control.CheckBox
        RateEditField matlab.ui.control.NumericEditField

        FontSet logical = false
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        PollingRateChanged
        PollingOverrideEnabled
        PollingOverrideDisabled
    end

    methods (Access = protected)

        function setup( obj ) 
            %Create grid layout to manage building blocks 
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", { 30 }, ...
                "ColumnWidth", {200, 70} , ...
                "Padding", 0, ...
                "ColumnSpacing", 22 );

            %Create checkbox
            obj.PollingCheckbox = uicheckbox( "Parent", obj.GridLayout, ...
                "Text", "Override IMU polling rate", ...
                "ValueChangedFcn", @obj.pollingOverrideToggled );

            %Create numeric input field
            obj.RateEditField = uieditfield( obj.GridLayout, ...
                "numeric", ...
                "ValueDisplayFormat", "%.0f Hz", ...
                "Limits", [1 inf], ...
                "Value", 60, ...
                "ValueChangedFcn", @obj.pollingRateChanged);
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
            if (obj.PollingCheckbox.Value == true)
                notify( obj, "PollingOverrideEnabled" )
                notify( obj, "PollingRateChanged" )
            else
                notify( obj, "PollingOverrideDisabled" )
            end      
        end
        
        function pollingRateChanged( obj, ~, ~ )
            obj.PollingRate = obj.RateEditField.Value;
            
            if (obj.PollingCheckbox.Value == true)
                notify( obj, "PollingRateChanged" )
            end
        end
    end
end

