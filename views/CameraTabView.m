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

        WebcamStatusLabel matlab.ui.control.Label
        WebcamDropDown matlab.ui.control.DropDown
        WebcamRefreshButton matlab.ui.control.Button
        WebcamConnectButton matlab.ui.control.Button

        IPCamStatusLabel matlab.ui.control.Label
        IPCamURLEditField matlab.ui.control.EditField
        IPCamUsernameEditField matlab.ui.control.EditField
        IPCamPasswordEditField matlab.ui.control.EditField
        IPCamConnectButton matlab.ui.control.Button
        IPCamFeedbackLabel matlab.ui.control.Label
    end

    events (NotifyAccess = private)
        %Event broadcast when view is interacted with
        RefreshWebcamsPushed
        ConnectWebcamPushed

        ConnectIPCamPushed

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
                "RowHeight", {22, 22, 30, 30, 30, 50, 22, 30, 30, 30, 30, 50}, ...
                "ColumnWidth", { 500 }, ...
                "Padding", 20 );

            %Wired webcam
            uilabel("Parent", obj.GridLayout, ...
                "Text", "Wired Webcam", ...
                "FontWeight", "bold");

            obj.WebcamStatusLabel = uilabel("Parent", obj.GridLayout, ...
                 "Text", "Not connected.");

            obj.WebcamRefreshButton = uibutton("Parent", obj.GridLayout, ...
                "Text", "Refresh available webcams", ...
                "ButtonPushedFcn", @obj.refreshWebcamsPushed);

            obj.WebcamDropDown = uidropdown("Parent", obj.GridLayout, ...
                "Placeholder", "No webcams available", ...
                "Items", "", ...
                "Enable", "off");

            obj.WebcamConnectButton = uibutton("Parent", obj.GridLayout, ...
                "Text", "Connect", ...
                "Enable", "off", ...
                "ButtonPushedFcn", @obj.connectWebcamPushed);

            %Wireless IP camera
            uilabel("Parent", obj.GridLayout, ...
                "Text", "Wireless IP Camera", ...
                "FontWeight", "bold", ...
                "VerticalAlignment", "bottom");

            obj.IPCamStatusLabel = uilabel("Parent", obj.GridLayout, ...
                 "Text", "Not connected.");

            obj.IPCamUsernameEditField = uieditfield("Parent", obj.GridLayout, ...
                "Placeholder", "Username");

            obj.IPCamPasswordEditField = uieditfield("Parent", obj.GridLayout, ...
                "Placeholder", "Password");

            obj.IPCamURLEditField = uieditfield("Parent", obj.GridLayout, ...
                "Placeholder", "RTSP URL", ...
                "Tooltip", "e.g. rtsp://192.168.1.123/stream1");
            
            obj.IPCamConnectButton = uibutton("Parent", obj.GridLayout, ...
                "Text", "Connect", ...
                "ButtonPushedFcn", @obj.connectIPCamPushed);

            obj.IPCamFeedbackLabel = uilabel("Parent", obj.GridLayout, ...
                 "Text", "", ...
                 "VerticalAlignment", "top");
        end

        function update(obj)

            if (~obj.FontSet)
                set(findall(obj.GridLayout, '-property', 'FontSize'), 'FontSize', obj.FontSize);
                obj.FontSet = true;
            end

        end

    end

    methods (Access = private)

        function refreshWebcamsPushed(obj, ~, ~)
            notify(obj, "RefreshWebcamsPushed")
        end

        function connectWebcamPushed(obj, ~, ~)
            notify(obj, "ConnectWebcamPushed")
        end

        function connectIPCamPushed(obj, ~, ~)
            notify(obj, "ConnectIPCamPushed")
        end
    end

end
