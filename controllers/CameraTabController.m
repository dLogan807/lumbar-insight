classdef CameraTabController < handle
    %Provides an interactive control to generate new data.

    properties (Access = private)
        % Application data model.
        Model(1, 1) Model
        % Camera View
        CameraTabView CameraTabView
        % Listener object used to respond dynamically to view events.
        Listener(:, 1) event.listener

    end % properties ( Access = private )

    methods

        function obj = CameraTabController(model, cameraTabView)
            %Controller constructor.

            arguments
                model(1, 1) Model
                cameraTabView CameraTabView
            end % arguments

            % Store the model and view
            obj.Model = model;
            obj.CameraTabView = cameraTabView;

            % Listen for changes to the view.
            obj.Listener(end + 1) = listener(obj.CameraTabView, ...
                "RefreshWebcamsPushed", @obj.refreshAvailableWebcams);
            obj.Listener(end + 1) = listener(obj.CameraTabView, ...
                "ConnectWebcamPushed", @obj.connectWebcamPushed);

            obj.Listener(end + 1) = listener(obj.CameraTabView, ...
                "ConnectIPCamPushed", @obj.connectIPCamPushed);

            % Listen for changes to the model.
            obj.Listener(end + 1) = listener(obj.Model, ...
                "WebcamConnected", @obj.webcamConnected);
            obj.Listener(end + 1) = listener(obj.Model, ...
                "WebcamDisconnected", @obj.webcamDisconnected);

            obj.Listener(end + 1) = listener(obj.Model, ...
                "IPCamConnected", @obj.ipCamConnected);
            obj.Listener(end + 1) = listener(obj.Model, ...
                "IPCamConnectFailed", @obj.ipCamConnectFailed);
            obj.Listener(end + 1) = listener(obj.Model, ...
                "IPCamDisconnected", @obj.ipCamDisconnected);

        end % constructor

    end % methods

    methods (Access = protected)

        function setup(~)
            %Initialize the controller.

        end % setup

        function update(~)
            %Update the controller. This method is empty because
            %there are no public properties of the controller.

        end % update

    end % methods ( Access = protected )

    methods (Access = private)
        function refreshAvailableWebcams(obj, ~, ~)
            %Update the available connected webcams
            webcams = webcamlist();
            obj.CameraTabView.WebcamDropDown.Items = webcams;

            if (isempty(webcams))
                obj.CameraTabView.WebcamDropDown.Enable = "off";
                obj.CameraTabView.WebcamConnectButton.Enable = "off";
                obj.Model.disconnectWebcam();
            else
                obj.CameraTabView.WebcamDropDown.Enable = "on";
                obj.CameraTabView.WebcamConnectButton.Enable = "on";
            end
        end

        function connectWebcamPushed(obj, ~, ~)
            %Connect or disconnect from a webcam

            if (obj.Model.Webcam.IsConnected)
                obj.Model.disconnectWebcam();
            else
                webcamName = obj.CameraTabView.WebcamDropDown.Value;
                obj.Model.connectWebcam(webcamName);
            end
        end

        function connectIPCamPushed(obj, ~, ~)
            %Connect or disconnect from an IP Camera, update UI

            if (obj.Model.IPCam.IsConnected)
                obj.Model.disconnectIPCam();
            else
                if (strlength(obj.CameraTabView.IPCamURLEditField.Value) <= 0)
                    obj.CameraTabView.IPCamFeedbackLabel.Text = "Please provide a RTSP URL.";
                    return
                else
                    obj.CameraTabView.IPCamFeedbackLabel.Text = "";
                end

                ipCamConnectingUI(obj);
                
                url = obj.CameraTabView.IPCamURLEditField.Value;
                username = obj.CameraTabView.IPCamUsernameEditField.Value;
                password = obj.CameraTabView.IPCamPasswordEditField.Value;

                obj.Model.connectIPCam(url, username, password);
            end
        end

        function ipCamConnectingUI(obj)
            %Disable fields while connecting to IP Camera
            obj.CameraTabView.IPCamUsernameEditField.Enable = "off";
            obj.CameraTabView.IPCamPasswordEditField.Enable = "off";
            obj.CameraTabView.IPCamURLEditField.Enable = "off";
            obj.CameraTabView.IPCamConnectButton.Enable = "off";
            obj.CameraTabView.IPCamConnectButton.Text = "Connecting";

            drawnow
        end

        function ipCamConnectUI(obj)
            %Show connection UI for IP Cam

            obj.CameraTabView.IPCamUsernameEditField.Enable = "on";
            obj.CameraTabView.IPCamPasswordEditField.Enable = "on";
            obj.CameraTabView.IPCamURLEditField.Enable = "on";

            obj.CameraTabView.IPCamConnectButton.Text = "Connect";
            obj.CameraTabView.IPCamConnectButton.Enable = "on";

            drawnow
        end

        function webcamConnected(obj, ~, ~)
            %Update UI after webcam connected

            obj.CameraTabView.WebcamDropDown.Enable = "off";
            obj.CameraTabView.WebcamRefreshButton.Enable = "off";
            obj.CameraTabView.WebcamConnectButton.Text = "Disconnect";
            obj.CameraTabView.WebcamStatusLabel.Text = "Connected to " + obj.Model.Webcam.Name;
        end

        function webcamDisconnected(obj, ~, ~)
            %Update UI after webcam disconnected

            obj.CameraTabView.WebcamRefreshButton.Enable = "on";
            obj.CameraTabView.WebcamConnectButton.Text = "Connect";
            obj.CameraTabView.WebcamStatusLabel.Text = "Not connected.";
            refreshAvailableWebcams(obj);
        end

        function ipCamConnected(obj, ~, ~)
            %Update UI after IP Camera connected

            obj.CameraTabView.IPCamConnectButton.Enable = "on";
            obj.CameraTabView.IPCamConnectButton.Text = "Disconnect";
            obj.CameraTabView.IPCamStatusLabel.Text = "Connected to IP Camera.";
        end

        function ipCamConnectFailed(obj, ~, ~)
            %Show feedback after failing to connect to IP Cam

            ipCamConnectUI(obj);
            obj.CameraTabView.IPCamFeedbackLabel.Text = obj.Model.IPCam.Feedback;
        end

        function ipCamDisconnected(obj, ~, ~)
            %Update UI after IP Camera disconnected

            ipCamConnectUI(obj);
            obj.CameraTabView.IPCamStatusLabel.Text = "Not connected.";
        end
        
    end % methods ( Access = private )

end % classdef
