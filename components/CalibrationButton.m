classdef CalibrationButton < matlab.ui.componentcontainer.ComponentContainer
    %DEVICECONNECT UI component for connecting to a device

    properties
        ButtonLabel string
        StatusText string
    end
    
    properties (Access = private, Transient, NonCopyable)
        Grid matlab.ui.container.GridLayout 
        CalibrateButton matlab.ui.control.Button
        CalibrationLabel matlab.ui.control.Label
    end

    events (HasCallbackProperty, NotifyAccess = protected) 
        CalibrateButtonPushed
    end

    methods (Access = protected)

        function setup( comp ) 
            % Create grid layout to manage building blocks 
            comp.Grid = uigridlayout( ...
                "Parent", comp, ...
                "RowHeight", { 22 }, ...
                "ColumnWidth", {"1x", "1x"} , ...
                "Padding", 0, ...
                "ColumnSpacing", 22 );

            % Create calibration button
            comp.CalibrateButton = uibutton(comp.Grid);
            comp.CalibrateButton.ButtonPushedFcn = @comp.calibrationButtonPushed;
            comp.CalibrateButton.Layout.Column = 1;

            % Create status text label
            comp.CalibrationLabel = uilabel(comp.Grid, ...
                "Text", "Not calibrated.");
            comp.CalibrationLabel.Layout.Column = 2;
        end

        function update( comp )
            %Update component properties
            comp.CalibrateButton.Text = comp.ButtonLabel;
        end
    end

    methods (Access = private)
        function calibrationButtonPushed( obj, ~, ~ )
            notify( obj, "CalibrateButtonPushed" )
        end
    end
end

