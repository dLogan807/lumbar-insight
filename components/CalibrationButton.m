classdef CalibrationButton < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONNECT UI component for connecting to a device

    properties
        ButtonLabel string
        StatusText string
        Enable logical = false
    end
    
    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout 
        CalibrateButton matlab.ui.control.Button
        CalibrationLabel matlab.ui.control.Label
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        CalibrateButtonPushed
    end

    methods (Access = protected)

        function setup( obj ) 
            % Create grid layout to manage building blocks 
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", { 22 }, ...
                "ColumnWidth", {"1x", "1x"} , ...
                "Padding", 0, ...
                "ColumnSpacing", 22 );

            % Create calibration button
            obj.CalibrateButton = uibutton(obj.GridLayout, ...
                "Enable", "off");
            obj.CalibrateButton.ButtonPushedFcn = @obj.calibrationButtonPushed;
            obj.CalibrateButton.Layout.Column = 1;

            % Create status text label
            obj.CalibrationLabel = uilabel(obj.GridLayout, ...
                "Text", "Not calibrated.");
            obj.CalibrationLabel.Layout.Column = 2;

            setFontSize( obj, 14 );
        end

        function update( obj )
            %Update component properties
            if (obj.ButtonLabel ~= "")
                obj.CalibrateButton.Text = obj.ButtonLabel;
            end

            if (obj.StatusText ~= "")
                obj.CalibrationLabel.Text = obj.StatusText;
            end

            if (obj.Enable)
                obj.CalibrateButton.Enable = "on";
            else
                obj.CalibrateButton.Enable = "off";
            end
        end
    end

    methods ( Access = public )
        function setFontSize( obj, fontSize )
            set(findall(obj.GridLayout,'-property','FontSize'), 'FontSize', fontSize);
        end
    end

    methods (Access = private)
        function calibrationButtonPushed( obj, ~, ~ )
            notify( obj, "CalibrateButtonPushed" )
        end
    end
end

