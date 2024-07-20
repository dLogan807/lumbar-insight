classdef SessionTabView < matlab.ui.componentcontainer.ComponentContainer
    %IMUTABVIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        GridLayout
        % Components
        
    end

    properties
        FontSize double = 12

        % Components
        LumbarAngleGraph matlab.ui.control.UIAxes

        TimeAboveMaxLabel matlab.ui.control.Label
        SmallestAngleLabel matlab.ui.control.Label
        LargestAngleLabel matlab.ui.control.Label

        AngleThresholdSlider matlab.ui.control.Slider

        SessionStartButton matlab.ui.control.Button
        SessionStopButton matlab.ui.control.Button

        IndicatorGraph matlab.ui.control.UIAxes
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

            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {"1x", 22, 40, 22, 22, 22}, ...
                "ColumnWidth", {"2x", "1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 50 );

            % Create view components.
            obj.LumbarAngleGraph = uiaxes( "Parent", obj.GridLayout );
            obj.LumbarAngleGraph.XLabel.String = 'Time (Seconds)';
            obj.LumbarAngleGraph.YLabel.String = 'Lumbosacral Angle (Degrees)';
            obj.LumbarAngleGraph.YLim = [0 360];
            obj.LumbarAngleGraph.XLim = [0 inf];
            obj.LumbarAngleGraph.Layout.Row = 1;
            obj.LumbarAngleGraph.Layout.Column = 1;

            sliderLabel = uilabel( "Parent", obj.GridLayout, ...
                "Text", "Percentage threshold of maximum angle" );
            sliderLabel.Layout.Row = 2;
            sliderLabel.Layout.Column = 1;

            obj.AngleThresholdSlider = uislider( "Parent", obj.GridLayout, ...
                "Value", 80, ...
                "ValueChangedFcn", @obj.onThresholdSliderValueChanged);
            obj.AngleThresholdSlider.Layout.Row = 3;
            obj.AngleThresholdSlider.Layout.Column = 1;

            obj.TimeAboveMaxLabel = uilabel( "Parent", obj.GridLayout, ...
                "Text", "Time above threshold angle: 0s");
            obj.TimeAboveMaxLabel.Layout.Row = 4;
            obj.TimeAboveMaxLabel.Layout.Column = 1;

            obj.SmallestAngleLabel = uilabel( "Parent", obj.GridLayout, ...
                "Text", "Smallest angle:");
            obj.SmallestAngleLabel.Layout.Row = 5;
            obj.SmallestAngleLabel.Layout.Column = 1;

            obj.LargestAngleLabel = uilabel( "Parent", obj.GridLayout, ...
                "Text", "Largest angle:");
            obj.LargestAngleLabel.Layout.Row = 6;
            obj.LargestAngleLabel.Layout.Column = 1;

            obj.SessionStartButton = uibutton( "Parent", obj.GridLayout, ...
                "Text", "Start Session", ...
                "ButtonPushedFcn", @obj.onSessionStartButtonPushed );
            obj.SessionStartButton.Layout.Row = 4;
            obj.SessionStartButton.Layout.Column = 2;

            obj.SessionStopButton = uibutton( "Parent", obj.GridLayout, ...
                "Text", "Stop Session", ...
                "Enable", "off", ...
                "ButtonPushedFcn", @obj.onSessionStopButtonPushed );
            obj.SessionStopButton.Layout.Row = 5;
            obj.SessionStopButton.Layout.Column = 2;

            obj.IndicatorGraph = uiaxes( "Parent", obj.GridLayout );
            obj.IndicatorGraph.YLabel.String = 'Lumbosacral Angle (Degrees)';
            obj.IndicatorGraph.YLim = [-90 180];
            obj.IndicatorGraph.XLim = [0 10];
            obj.IndicatorGraph.Layout.Row = [1 3];
            obj.IndicatorGraph.Layout.Column = 2;
            %Draw traffic light indicator colours
            rectangle("Parent", obj.IndicatorGraph, ...
                "FaceColor","#f26b67", ...
                "EdgeColor","none", ...
                "Position", [0 -90 10 270] )
            rectangle("Parent", obj.IndicatorGraph, ...
                "FaceColor","#f6ee5d", ...
                "EdgeColor","none", ...
                "Position", [0 -90 10 270] );
            rectangle("Parent", obj.IndicatorGraph, ...
                "FaceColor","#bfda69", ...
                "EdgeColor","none", ...
                "Position", [0 -90 10 270] );
        end

        function update( obj )
            set(findall(obj.GridLayout,'-property','FontSize'),'FontSize', obj.FontSize);
        end

    end

    methods ( Access = private )
        function onThresholdSliderValueChanged( obj, ~, ~ )
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