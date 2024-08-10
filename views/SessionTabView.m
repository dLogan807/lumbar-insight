classdef SessionTabView < matlab.ui.componentcontainer.ComponentContainer
    %Visualizes the data, responding to any relevant model events.

    properties ( Access = private )
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener
        
        FontSet logical = false

        AngleUpdated = false

        yAxisMinimum = -50
        yAxisMaximum = 90
        yAxisTickInterval = 10
    end

    properties
        FontSize double = 12
        FullFlexionAngle double = 30

        %Components
        GridLayout matlab.ui.container.GridLayout

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
        %Event broadcast when view is interacted with
        ThresholdSliderValueChanged
        SessionStartButtonPushed
        SessionStopButtonPushed

    end % events ( NotifyAccess = private )
        
    methods

        function obj = SessionTabView( namedArgs )
            %View constructor.

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

    methods
        function set.FullFlexionAngle( obj, angle)
            obj.FullFlexionAngle = angle;
            obj.AngleUpdated = true;
        end
    end

    methods ( Access = protected )

        function setup( obj )
            %Initialize the view.

            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {"1x", 22, 40, 30, 30, 22}, ...
                "ColumnWidth", {"2x", ".5x", "1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 100 );

            %Create view components.

            %Graph
            obj.LumbarAngleGraph = uiaxes( "Parent", obj.GridLayout, ...
                "XLim", [0 30], ...
                "YLim", [obj.yAxisMinimum obj.yAxisMaximum], ...
                "YTick", obj.yAxisMinimum:obj.yAxisTickInterval:obj.yAxisMaximum);
            obj.LumbarAngleGraph.XLabel.String = 'Time (Seconds)';
            obj.LumbarAngleGraph.YLabel.String = 'Lumbosacral Angle (Degrees)';
            obj.LumbarAngleGraph.Layout.Row = 1;
            obj.LumbarAngleGraph.Layout.Column = 1;

            %Threshold slider
            sliderLabel = uilabel( "Parent", obj.GridLayout, ...
                "Text", "Percentage threshold of maximum angle" );
            sliderLabel.Layout.Row = 2;
            sliderLabel.Layout.Column = 1;

            obj.AngleThresholdSlider = uislider( "Parent", obj.GridLayout, ...
                "Value", 80, ...
                "ValueChangedFcn", @obj.onThresholdSliderValueChanged);
            obj.AngleThresholdSlider.Layout.Row = 3;
            obj.AngleThresholdSlider.Layout.Column = 1;

            %Session data
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

            %Session control
            obj.SessionStartButton = uibutton( "Parent", obj.GridLayout, ...
                "Text", "Start Session", ...
                "Enable", "off", ...
                "ButtonPushedFcn", @obj.onSessionStartButtonPushed );
            obj.SessionStartButton.Layout.Row = 4;
            obj.SessionStartButton.Layout.Column = 2;

            obj.SessionStopButton = uibutton( "Parent", obj.GridLayout, ...
                "Text", "Stop Session", ...
                "Enable", "off", ...
                "ButtonPushedFcn", @obj.onSessionStopButtonPushed );
            obj.SessionStopButton.Layout.Row = 5;
            obj.SessionStopButton.Layout.Column = 2;

            obj.IndicatorGraph = uiaxes( "Parent", obj.GridLayout, ...
                "XLim", [0 1], ...
                "YLim", [obj.yAxisMinimum obj.yAxisMaximum], ...
                "XTick", [], ...
                "YTick", obj.yAxisMinimum:obj.yAxisTickInterval:obj.yAxisMaximum, ...
                "Layer", "top", ...
                "Colormap", CustomColourMaps.TrafficLight);
            obj.IndicatorGraph.YLabel.String = 'Lumbosacral Angle (Degrees)';
            obj.IndicatorGraph.Layout.Row = 1;
            obj.IndicatorGraph.Layout.Column = 2;

            updateTrafficLightGraph( obj );
        end

        function update( obj )
            if (~obj.FontSet)
                set(findall(obj.GridLayout,'-property','FontSize'),'FontSize', obj.FontSize);
                obj.FontSet = true;
            end

            if (obj.AngleUpdated)
                updateTrafficLightGraph( obj );
                obj.AngleUpdated = false;
            end
        end

        function updateTrafficLightGraph( obj )
            %Draw traffic light indicator graph gradient

            upperMax = obj.FullFlexionAngle * 0.8;
            upperWarn = obj.FullFlexionAngle * 0.6;
            standing = 0;
            lowerWarn = obj.FullFlexionAngle * -0.1;
            lowerMax = obj.FullFlexionAngle * -0.2;

            red = 0;
            green = 1;
            yellow = 0.6;
            amber = 0.25;

            x = [0 1 1 1 1 1 1 1 0 0 0 0 0 0];
            y = [obj.yAxisMinimum obj.yAxisMinimum lowerMax lowerWarn standing upperWarn upperMax obj.yAxisMaximum obj.yAxisMaximum upperMax upperWarn standing lowerWarn lowerMax];
            c = [red; red; amber; yellow; green; yellow; amber; red; red; amber; yellow; green; yellow; amber];
            fill(obj.IndicatorGraph,x,y,c, "EdgeColor","none");
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