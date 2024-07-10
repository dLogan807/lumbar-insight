classdef SessionTabView < matlab.ui.componentcontainer.ComponentContainer
    %IMUTABVIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        %Components
        
    end

    properties

    end

    events ( NotifyAccess = private )
        % Event broadcast when view is interacted with

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
            lumbarAngleGraph = uiaxes( "Parent", gridLayout );
            lumbarAngleGraph.XLabel.String = 'Time (Seconds)';
            lumbarAngleGraph.YLabel.String = 'Lumbosacral Angle';
            lumbarAngleGraph.Layout.Row = 1;
            lumbarAngleGraph.Layout.Column = 1;

            sliderLabel = uilabel( "Parent", gridLayout, ...
                "Text", "Percentage threshold of maximum angle" );
            sliderLabel.Layout.Row = 2;
            sliderLabel.Layout.Column = 1;

            angleThresholdSlider = uislider( "Parent", gridLayout, ...
                "Value", 80);
            angleThresholdSlider.Layout.Row = 3;
            angleThresholdSlider.Layout.Column = 1;

            timeAboveMaxLabel = uilabel( "Parent", gridLayout, ...
                "Text", "Time above threshold angle: 0s");
            timeAboveMaxLabel.Layout.Row = 4;
            timeAboveMaxLabel.Layout.Column = 1;

            smallestAngleLabel = uilabel( "Parent", gridLayout, ...
                "Text", "Smallest angle:");
            smallestAngleLabel.Layout.Row = 5;
            smallestAngleLabel.Layout.Column = 1;

            largestAngleLabel = uilabel( "Parent", gridLayout, ...
                "Text", "Largest angle:");
            largestAngleLabel.Layout.Row = 6;
            largestAngleLabel.Layout.Column = 1;
        end

        function update( ~ )
        end

    end

    methods ( Access = private )


    end

end