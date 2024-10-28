classdef CameraTabView < matlab.ui.componentcontainer.ComponentContainer
    %Visualizes the data, responding to any relevant model events.

    properties (Access = private)
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        FontSet logical = false
    end

    properties
        FontSize double = 12

        %Components
        GridLayout matlab.ui.container.GridLayout

        WebcamDropDown matlab.ui.control.DropDown
        WebcamStatusLabel matlab.ui.control.Label
        WebcamRefreshButton matlab.ui.control.Button
        WebcamConnectButton matlab.ui.control.Button
    end

    events (NotifyAccess = private)
        %Event broadcast when view is interacted with
        

    end % events ( NotifyAccess = private )

    methods

        function obj = CameraTabView(namedArgs)
            %View constructor.

            arguments
                namedArgs.?CameraTabView
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

        end
    end

    methods (Access = protected)

        function setup(obj)
            %Initialize the view.

            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {22, 22, 30, 30, 30, 22}, ...
                "ColumnWidth", {"1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 40);

            %Wired webcam
            webcamLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Wired Webcam", ...
                "FontWeight", "bold");
            webcamLabel.Layout.Row = 1;

            obj.WebcamStatusLabel = uilabel("Parent", obj.GridLayout, ...
                 "Text", "Status: Not connected.");
            obj.WebcamStatusLabel.Layout.Row = 2;

            obj.WebcamRefreshButton = uibutton("Parent", obj.GridLayout, ...
                "Text", "Refresh available webcams");
            obj.WebcamRefreshButton.Layout.Row = 3;

            initalWebcams = webcamlist;
            obj.WebcamDropDown = uidropdown("Parent", obj.GridLayout, ...
                "Items", initalWebcams, ...
                "Placeholder", "No webcams available");
            if (isempty(initalWebcams))
                obj.WebcamDropDown.Enable = "off";
            end
            obj.WebcamDropDown.Layout.Row = 4;

            obj.WebcamConnectButton = uibutton("Parent", obj.GridLayout, ...
                "Text", "Connect");
            obj.WebcamConnectButton.Layout.Row = 5;

            %Wireless IP camera
            webcamLabel = uilabel("Parent", obj.GridLayout, ...
                "Text", "Wireless IP Camera", ...
                "FontWeight", "bold");
            webcamLabel.Layout.Row = 6;
            
        end

        function update(obj)

            if (~obj.FontSet)
                set(findall(obj.GridLayout, '-property', 'FontSize'), 'FontSize', obj.FontSize);
                obj.FontSet = true;
            end

        end

    end

    methods (Access = private)

    end

end
