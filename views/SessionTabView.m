classdef SessionTabView < matlab.ui.componentcontainer.ComponentContainer
    %Visualizes the data, responding to any relevant model events.

    properties (Access = private)
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        FontSet logical = false

        YAxisMinimum = -50
        YAxisMaximum = 90
        YAxisTickInterval = 10
    end

    properties
        FontSize double = 12

        %Components
        GridLayout matlab.ui.container.GridLayout
        DataOverviewLayout matlab.ui.container.GridLayout
        GraphLayout matlab.ui.container.GridLayout

        LumbarAngleGraph matlab.ui.control.UIAxes
        IndicatorGraph matlab.ui.control.UIAxes

        StreamingTimeAboveThresholdLabel matlab.ui.control.Label
        StreamingSmallestAngleLabel matlab.ui.control.Label
        StreamingLargestAngleLabel matlab.ui.control.Label
        StreamingTimeLabel matlab.ui.control.Label

        RecordedTimeAboveThresholdLabel matlab.ui.control.Label
        RecordedSmallestAngleLabel matlab.ui.control.Label
        RecordedLargestAngleLabel matlab.ui.control.Label
        RecordingTimeLabel matlab.ui.control.Label

        AngleThresholdLabel matlab.ui.control.Label
        AngleThresholdSlider matlab.ui.control.Slider

        WarningBeepField BeepConfigField

        StartStreamingButton matlab.ui.control.Button
        StopStreamingButton matlab.ui.control.Button
        RecordingButton matlab.ui.control.Button

        WebcamStatusLabel matlab.ui.control.Label
        WebcamRecordCheckbox matlab.ui.control.CheckBox
        WebcamAxes matlab.ui.control.UIAxes

        IPCamStatusLabel matlab.ui.control.Label
        IPCamRecordCheckbox matlab.ui.control.CheckBox
        IPCamAxes matlab.ui.control.UIAxes
    end

    events (NotifyAccess = private)
        %Event broadcast when view is interacted with
        BeepRateChanged
        BeepToggled
        ThresholdSliderValueChanged
        StartStreamingButtonPushed
        StopStreamingButtonPushed
        RecordingButtonPushed

    end % events ( NotifyAccess = private )

    methods

        function obj = SessionTabView(namedArgs)
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
                "Position", [0, 0, 1, 1])

            % Set any user-specified properties.
            set(obj, namedArgs)

            % Listen for changes in components
            obj.Listener(end + 1) = listener(obj.WarningBeepField, ...
                "BeepToggled", @obj.onBeepToggled);
            obj.Listener(end + 1) = listener(obj.WarningBeepField, ...
                "BeepRateChanged", @obj.onBeepRateChanged);
        end

    end

    methods

        function setThresholdLabelPercentage(obj, percentage)
            %Update the percentage value on the slider

            arguments
                obj
                percentage double {mustBePositive}
            end

            obj.AngleThresholdLabel.Text = "Percentage threshold of Full Flexion angle: " + percentage + "%";
        end

        function updateTrafficLightGraph(obj, fullFlexionAngle, decimalPercentage)
            %Draw traffic light indicator graph gradient

            arguments
                obj
                fullFlexionAngle double {mustBeNonempty}
                decimalPercentage double {mustBePositive, mustBeNonempty}
            end

            upperMax = fullFlexionAngle * decimalPercentage;
            upperWarn = fullFlexionAngle * (decimalPercentage - 0.2);
            standing = 0;
            lowerWarn = fullFlexionAngle * -0.1;
            lowerMax = fullFlexionAngle * -0.2;

            red = 0;
            amber = 0.25;
            yellow = 0.6;
            green = 1;

            x = [0 1 1 1 1 1 1 1 0 0 0 0 0 0];
            y = [obj.YAxisMinimum obj.YAxisMinimum lowerMax lowerWarn standing upperWarn upperMax obj.YAxisMaximum obj.YAxisMaximum upperMax upperWarn standing lowerWarn lowerMax];
            c = [red; red; amber; yellow; green; yellow; amber; red; red; amber; yellow; green; yellow; amber];
            fill(obj.IndicatorGraph, x, y, c, "EdgeColor", "none");
        end

    end

    methods (Access = protected)

        function setup(obj)
            %Initialize the view.

            %Setup layout
            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {22, "1x", 22, 30, 40, 30, 30}, ...
                "ColumnWidth", {"2x", ".5x", "1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 40);

            obj.GraphLayout = uigridlayout( ...
                "Parent", obj.GridLayout, ...
                "RowHeight", {"1x"}, ...
                "ColumnWidth", {"7x", "1x"}, ...
                "Padding", 0, ...
                "ColumnSpacing", 10);
            obj.GraphLayout.Layout.Row = [1 2];
            obj.GraphLayout.Layout.Column = [1 2];

            obj.DataOverviewLayout = uigridlayout( ...
                "Parent", obj.GridLayout, ...
                "RowHeight", {"1x"}, ...
                "ColumnWidth", {"1.5x", "1x", "1x"}, ...
                "Padding", 0, ...
                "ColumnSpacing", 10);
            obj.DataOverviewLayout.Layout.Row = [3 7];
            obj.DataOverviewLayout.Layout.Column = 3;

            cameraGrid = uigridlayout( ...
                "Parent", obj.GridLayout, ...
                "RowHeight", {22, 22, 22, "1x", 22, 22, 22, "1x"}, ...
                "ColumnWidth", {"1x"} );
            cameraGrid.Layout.Row = [1 2];
            cameraGrid.Layout.Column = 3;

            %Create view components.

            %Graphs
            obj.LumbarAngleGraph = uiaxes("Parent", obj.GraphLayout, ...
                "XLim", [0 30], ...
                "YLim", [obj.YAxisMinimum obj.YAxisMaximum], ...
                "YTick", obj.YAxisMinimum:obj.YAxisTickInterval:obj.YAxisMaximum);
            obj.LumbarAngleGraph.XLabel.String = 'Time (Seconds)';
            obj.LumbarAngleGraph.YLabel.String = 'Lumbosacral Angle (Degrees)';
            obj.LumbarAngleGraph.Layout.Column = 1;

            obj.IndicatorGraph = uiaxes("Parent", obj.GraphLayout, ...
                "XLim", [0 1], ...
                "YLim", [obj.YAxisMinimum obj.YAxisMaximum], ...
                "YTick", obj.YAxisMinimum:obj.YAxisTickInterval:obj.YAxisMaximum, ...
                "XTick", 0:1, ...
                "YAxisLocation", "right", ...
                "Layer", "top", ...
                "Colormap", CustomColourMaps.TrafficLight);
            obj.IndicatorGraph.Toolbar.Visible = "off";
            disableDefaultInteractivity(obj.IndicatorGraph);
            obj.LumbarAngleGraph.XLabel.String = '';
            obj.IndicatorGraph.Layout.Column = 2;

            initialSliderValue = 80;
            placeholderFullFlexion = 30;
            updateTrafficLightGraph(obj, placeholderFullFlexion, initialSliderValue);

            %Threshold slider
            thresholdLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Threshold Configuration", ...
                "FontWeight", "bold");
            thresholdLabel.Layout.Row = 3;
            thresholdLabel.Layout.Column = 1;

            obj.AngleThresholdLabel = uilabel("Parent", obj.GridLayout);
            obj.AngleThresholdLabel.Layout.Row = 4;
            obj.AngleThresholdLabel.Layout.Column = 1;

            obj.AngleThresholdSlider = uislider("Parent", obj.GridLayout, ...
                "Value", initialSliderValue, ...
                "Limits", [1 100], ...
                "ValueChangedFcn", @obj.onThresholdSliderValueChanged);
            obj.AngleThresholdSlider.Layout.Row = 5;
            obj.AngleThresholdSlider.Layout.Column = 1;

            setThresholdLabelPercentage(obj, obj.AngleThresholdSlider.Value);

            %Warning beep configuration
            obj.WarningBeepField = BeepConfigField("Parent", obj.GridLayout, ...
                "FontSize", obj.FontSize);
            obj.WarningBeepField.Layout.Row = 6;
            obj.WarningBeepField.Layout.Column = 1;

            %Session data headings and rows
            sessionDataHeaderLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "Session Stats", ...
                "FontWeight", "bold");
            sessionDataHeaderLabel.Layout.Row = 1;
            sessionDataHeaderLabel.Layout.Column = 2;

            sessionDataHeaderLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "Recording Stats", ...
                "FontWeight", "bold");
            sessionDataHeaderLabel.Layout.Row = 1;
            sessionDataHeaderLabel.Layout.Column = 3;

            sessionTimeRowLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "Time streaming");
            sessionTimeRowLabel.Layout.Row = 2;
            sessionTimeRowLabel.Layout.Column = 1;

            thresholdTimeRowLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "Time above threshold");
            thresholdTimeRowLabel.Layout.Row = 3;
            thresholdTimeRowLabel.Layout.Column = 1;

            smallestAngleRowLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "Smallest angle");
            smallestAngleRowLabel.Layout.Row = 4;
            smallestAngleRowLabel.Layout.Column = 1;

            largestAngleRowLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "Largest angle");
            largestAngleRowLabel.Layout.Row = 5;
            largestAngleRowLabel.Layout.Column = 1;

            %Session data
            obj.StreamingTimeLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "0s");
            obj.StreamingTimeLabel.Layout.Row = 2;
            obj.StreamingTimeLabel.Layout.Column = 2;

            obj.StreamingTimeAboveThresholdLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "0s");
            obj.StreamingTimeAboveThresholdLabel.Layout.Row = 3;
            obj.StreamingTimeAboveThresholdLabel.Layout.Column = 2;

            obj.StreamingSmallestAngleLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "No data");
            obj.StreamingSmallestAngleLabel.Layout.Row = 4;
            obj.StreamingSmallestAngleLabel.Layout.Column = 2;

            obj.StreamingLargestAngleLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "No data");
            obj.StreamingLargestAngleLabel.Layout.Row = 5;
            obj.StreamingLargestAngleLabel.Layout.Column = 2;

            %Data recorded to file
            obj.RecordingTimeLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "0s");
            obj.RecordingTimeLabel.Layout.Row = 2;
            obj.RecordingTimeLabel.Layout.Column = 3;

            obj.RecordedTimeAboveThresholdLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "0s");
            obj.RecordedTimeAboveThresholdLabel.Layout.Row = 3;
            obj.RecordedTimeAboveThresholdLabel.Layout.Column = 3;

            obj.RecordedSmallestAngleLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "No data");
            obj.RecordedSmallestAngleLabel.Layout.Row = 4;
            obj.RecordedSmallestAngleLabel.Layout.Column = 3;

            obj.RecordedLargestAngleLabel = uilabel("Parent", obj.DataOverviewLayout, ...
                "Text", "No data");
            obj.RecordedLargestAngleLabel.Layout.Row = 5;
            obj.RecordedLargestAngleLabel.Layout.Column = 3;

            %Streaming control
            streamingLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Streaming", ...
                "FontWeight", "bold");
            streamingLabel.Layout.Row = 3;
            streamingLabel.Layout.Column = 2;

            streamingButtonGrid = uigridlayout( ...
                "Parent", obj.GridLayout, ...
                "RowHeight", {30}, ...
                "ColumnWidth", {"1x", "1x"}, ...
                "Padding", 0, ...
                "ColumnSpacing", 10);
            streamingButtonGrid.Layout.Row = 4;
            streamingButtonGrid.Layout.Column = 2;

            obj.StartStreamingButton = uibutton("Parent", streamingButtonGrid, ...
                "Text", "Start Streaming", ...
                "Enable", "off", ...
                "ButtonPushedFcn", @obj.onStartStreamingButtonPushed);
            obj.StartStreamingButton.Layout.Row = 1;
            obj.StartStreamingButton.Layout.Column = 1;

            obj.StopStreamingButton = uibutton("Parent", streamingButtonGrid, ...
                "Text", "Stop Streaming", ...
                "Enable", "off", ...
                "ButtonPushedFcn", @obj.onStopStreamingButtonPushed);
            obj.StopStreamingButton.Layout.Row = 1;
            obj.StopStreamingButton.Layout.Column = 2;

            %Recording control
            recordingLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Recording", ...
                "FontWeight", "bold");
            recordingLabel.Layout.Row = 5;
            recordingLabel.Layout.Column = 2;

            obj.RecordingButton = uibutton("Parent", obj.GridLayout, ...
                "Text", "Start Recording", ...
                "Enable", "off", ...
                "ButtonPushedFcn", @obj.onRecordingButtonPushed);
            obj.RecordingButton.Layout.Row = 6;
            obj.RecordingButton.Layout.Column = 2;

            %Webcam
             uilabel("Parent", cameraGrid, ...
                "Text", "Wired Webcam", ...
                "FontWeight", "bold");

            obj.WebcamStatusLabel = uilabel("Parent", cameraGrid, ...
                "Text", "No webcam connected.");

            obj.WebcamRecordCheckbox = uicheckbox("Parent", cameraGrid, ...
                "Text", "Record video", ...
                "Value", 1, ...
                "Enable", "off");

            obj.WebcamAxes = uiaxes("Parent", cameraGrid, ...
                "XTick", [], ...
                "YTick", [], ...
                "Visible", "off");
            obj.WebcamAxes.Toolbar.Visible = "off";
            disableDefaultInteractivity(obj.WebcamAxes);
            axis(obj.WebcamAxes, 'image');

            %IP Cam
            uilabel("Parent", cameraGrid, ...
                "Text", "Wireless IP Camera", ...
                "FontWeight", "bold");

            obj.IPCamStatusLabel = uilabel("Parent", cameraGrid, ...
                "Text", "No IP Camera connected.");

            obj.IPCamRecordCheckbox = uicheckbox("Parent", cameraGrid, ...
                "Text", "Record video", ...
                "Value", 1, ...
                "Enable", "off");

            obj.IPCamAxes = uiaxes("Parent", cameraGrid, ...
                "XTick", [], ...
                "YTick", [], ...
                "Visible", "off");
            obj.IPCamAxes.Toolbar.Visible = "off";
            disableDefaultInteractivity(obj.IPCamAxes);
            axis(obj.IPCamAxes, 'image');
            
        end

        function update(obj)

            if (~obj.FontSet)
                set(findall(obj.GridLayout, '-property', 'FontSize'), 'FontSize', obj.FontSize);
                obj.FontSet = true;
            end

        end

    end

    methods (Access = private)

        function onThresholdSliderValueChanged(obj, ~, ~)
            notify(obj, "ThresholdSliderValueChanged")
        end

        function onStartStreamingButtonPushed(obj, ~, ~)
            notify(obj, "StartStreamingButtonPushed")
        end

        function onStopStreamingButtonPushed(obj, ~, ~)
            notify(obj, "StopStreamingButtonPushed")
        end

        function onRecordingButtonPushed(obj, ~, ~)
            notify(obj, "RecordingButtonPushed")
        end

        function onBeepToggled(obj, ~, ~)
            notify(obj, "BeepToggled")
        end

        function onBeepRateChanged(obj, ~, ~)
            notify(obj, "BeepRateChanged")
        end

    end

end
