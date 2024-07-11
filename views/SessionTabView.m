classdef SessionTabView < matlab.ui.componentcontainer.ComponentContainer
    %IMUTABVIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        %Components
        
    end

    properties
        LumbarAngleGraph matlab.ui.control.UIAxes

        TimeAboveMaxLabel matlab.ui.control.Label
        SmallestAngleLabel matlab.ui.control.Label
        LargestAngleLabel matlab.ui.control.Label

        AngleThresholdSlider matlab.ui.control.Slider

        SessionStartButton matlab.ui.control.Button
        SessionStopButton matlab.ui.control.Button
    end

    events ( NotifyAccess = private )
        % Event broadcast when view is interacted with
        ThresholdSliderValueChanged
        SessionStartButtonPushed
        SessionStopButtonPushed

    end % events ( NotifyAccess = private )
        
    methods

        function obj = SessionTabView( namedArgs )
            %VIEW View constructor.

            arguments
                namedArgs.?SessionTabView
            end % arguments

            % Do not create a default figure parent for the component, and
            % ensure that the component spans its parent. By default,
            % ComponentContainer objects are auto-parenting - that is, a
            % figure is created automatically if no parent argument is
            % specified.
            obj@matlab.ui.componentcontainer.ComponentContainer( ...
                "Parent", [], ...
                "Units", "normalized", ...
                "Position", [0, 0, 1, 1] )

            % Set any user-specified properties.
            set( obj, namedArgs )

            % Listen for changes in components

        end
    end

    methods ( Access = protected )

        function setup( obj )
            %SETUP Initialize the view.

            gridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {"1x", 22, 40, 22, 22, 22}, ...
                "ColumnWidth", {"1x", "1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 50 );

            % Create view components.
            obj.LumbarAngleGraph = uiaxes( "Parent", gridLayout );
            obj.LumbarAngleGraph.XLabel.String = 'Time (Seconds)';
            obj.LumbarAngleGraph.YLabel.String = 'Lumbosacral Angle (Degrees)';
            obj.LumbarAngleGraph.YLim = [0 360];
            obj.LumbarAngleGraph.XLim = [0 inf];
            obj.LumbarAngleGraph.Layout.Row = 1;
            obj.LumbarAngleGraph.Layout.Column = 1;

            sliderLabel = uilabel( "Parent", gridLayout, ...
                "Text", "Percentage threshold of maximum angle" );
            sliderLabel.Layout.Row = 2;
            sliderLabel.Layout.Column = 1;

            obj.AngleThresholdSlider = uislider( "Parent", gridLayout, ...
                "Value", 80, ...
                "", "", ...
                "ValueChangedFcn", @obj.onThresholdSliderValueChanged);
            obj.AngleThresholdSlider.Layout.Row = 3;
            obj.AngleThresholdSlider.Layout.Column = 1;

            obj.TimeAboveMaxLabel = uilabel( "Parent", gridLayout, ...
                "Text", "Time above threshold angle: 0s");
            obj.TimeAboveMaxLabel.Layout.Row = 4;
            obj.TimeAboveMaxLabel.Layout.Column = 1;

            obj.SmallestAngleLabel = uilabel( "Parent", gridLayout, ...
                "Text", "Smallest angle:");
            obj.SmallestAngleLabel.Layout.Row = 5;
            obj.SmallestAngleLabel.Layout.Column = 1;

            obj.LargestAngleLabel = uilabel( "Parent", gridLayout, ...
                "Text", "Largest angle:");
            obj.LargestAngleLabel.Layout.Row = 6;
            obj.LargestAngleLabel.Layout.Column = 1;

            obj.SessionStartButton = uibutton( "Parent", gridLayout, ...
                "Text", "Start Session", ...
                "ButtonPushedFcn", @obj.onSessionStartButtonPushed );
            obj.SessionStartButton.Layout.Row = 4;
            obj.SessionStartButton.Layout.Column = 2;

            obj.SessionStopButton = uibutton( "Parent", gridLayout, ...
                "Text", "Stop Session", ...
                "ButtonPushedFcn", @obj.onSessionStopButtonPushed );
            obj.SessionStopButton.Layout.Row = 5;
            obj.SessionStopButton.Layout.Column = 2;

        end

        function update( ~ )
        end

    end

    methods ( Access = private )
        function onThresholdSliderValueChanged( obj, ~, ~ )
            disp("View: " + obj.AngleThresholdSlider.Value);
            notify( obj, "ThresholdSliderValueChanged" )
        end

        function onSessionStartButtonPushed( obj, ~, ~ )
            notify( obj, "SessionStartButtonPushed" )
        end

        function onSessionStopButtonPushed( obj, ~, ~ )
            notify( obj, "SessionStopButtonPushed" )
        end

    end

end