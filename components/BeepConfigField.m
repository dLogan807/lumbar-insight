classdef BeepConfigField < matlab.ui.componentcontainer.ComponentContainer
    %UI component for overriding the polling rate to IMUs

    properties
        FontSize double = 12
    end

    properties (GetAccess = public, SetAccess = private)
        RateEditField matlab.ui.control.NumericEditField
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        BeepCheckbox matlab.ui.control.CheckBox

        FontSet logical = false
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        BeepRateChanged
        BeepEnabled
        BeepDisabled
    end

    methods (Access = protected)

        function setup( obj ) 
            %Create grid layout to manage building blocks 
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", { 30 }, ...
                "ColumnWidth", {105, 100, 150}, ...
                "Padding", 0, ...
                "ColumnSpacing", 10 );

            %Create checkbox
            obj.BeepCheckbox = uicheckbox( "Parent", obj.GridLayout, ...
                "Text", " Beep every", ...
                "Value", 1, ...
                "ValueChangedFcn", @obj.beepEnabledToggled );

            %Create numeric input field
            obj.RateEditField = uieditfield( obj.GridLayout, ...
                "numeric", ...
                "ValueDisplayFormat", "%.0f seconds", ...
                "Limits", [0.1 inf], ...
                "Value", 1, ...
                "ValueChangedFcn", @obj.beepRateChanged);

            %Create label
            uilabel("Parent", obj.GridLayout, ...
                "Text", "above threshold");
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
        function beepEnabledToggled( obj, ~, ~ )
            if (obj.BeepCheckbox.Value == true)
                notify( obj, "BeepEnabled" )
                notify( obj, "BeepRateChanged" )
            else
                notify( obj, "BeepDisabled" )
            end      
        end
        
        function beepRateChanged( obj, ~, ~ )
            if (obj.BeepCheckbox.Value == true)
                notify( obj, "BeepRateChanged" )
            end
        end
    end
end

