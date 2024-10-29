classdef SessionTabController < handle
    %Provides an interactive control to generate new data.

    properties (Access = private)
        % Application data model.
        Model(1, 1) Model
        % Session View
        SessionTabView SessionTabView
        % Listener object used to respond dynamically to view events.
        Listener(:, 1) event.listener

        %Graph lines
        LumbarAngleLine
        ThresholdLine
        GradientLine
    end % properties ( Access = private )

    methods

        function obj = SessionTabController(model, sessionTabView)
            %Controller constructor.

            arguments
                model(1, 1) Model
                sessionTabView SessionTabView
            end % arguments

            % Store the model and view
            obj.Model = model;
            obj.SessionTabView = sessionTabView;

            % Listen for changes to the view.
            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "StartStreamingButtonPushed", @obj.onStartStreamingButtonPushed);
            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "StopStreamingButtonPushed", @obj.onStopStreamingButtonPushed);

            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "ThresholdSliderValueChanged", @obj.onThresholdSliderValueChanged);
            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "RecordingButtonPushed", @obj.onRecordingButtonPushed);

            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "BeepToggled", @obj.onBeepToggled);
            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "BeepRateChanged", @obj.onBeepRateChanged);

            % Listen for changes to the model data.
            obj.Listener(end + 1) = listener(obj.Model, ...
                "DevicesConnectedChanged", @obj.onDevicesConnectedChanged);
            obj.Listener(end + 1) = listener(obj.Model, ...
                "StandingOffsetAngleCalibrated", @obj.onStandingOffsetAngleCalibrated);
            obj.Listener(end + 1) = listener(obj.Model, ...
                "FullFlexionAngleCalibrated", @obj.onFullFlexionAngleCalibrated);
            obj.Listener(end + 1) = listener(obj.Model, ...
                "WebcamConnected", @obj.onWebCamConnected);

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

        function onDevicesConnectedChanged(obj, ~, ~)
            updateSessionEnabled(obj);
        end

        function onStandingOffsetAngleCalibrated(obj, ~, ~)
            updateSessionEnabled(obj);
        end

        function onFullFlexionAngleCalibrated(obj, ~, ~)
            updateSessionEnabled(obj);
            updateThresholdData(obj)
        end

        function onThresholdSliderValueChanged(obj, ~, ~)
            if (obj.Model.calibrationCompleted())
                updateThresholdData(obj);
            end
        end

        function onWebCamConnected(obj, ~, ~)
            %Get image size of camera and preview
            camImage = image(obj.SessionTabView.WebcamAxes, zeros(size(obj.Model.Webcam.Frame),'uint8'));

            obj.Model.Webcam.preview(camImage);

            obj.SessionTabView.WebcamAxes.Visible = "on";
        end

        function onWebCamDisconnected(obj, ~, ~)
            %Disable image preview axes component on disconnect
            obj.SessionTabView.WebCamAxes.Visible = "off";
        end

        function updateThresholdData(obj)
            %Update data and graphs relating to the threshold angle

            wholePercentageValue = round(obj.SessionTabView.AngleThresholdSlider.Value);

            obj.Model.setThresholdValues(wholePercentageValue);

            obj.SessionTabView.updateTrafficLightGraph(obj.Model.FullFlexionAngle, obj.Model.DecimalThresholdPercentage);
            obj.SessionTabView.setThresholdLabelPercentage(wholePercentageValue);
        end

        function updateSessionEnabled(obj)
            %Enable session control buttons depending on
            %angle calibration

            if (obj.Model.bothIMUDevicesConnected() && obj.Model.calibrationCompleted())
                obj.SessionTabView.StartStreamingButton.Enable = "on";
            else
                stopStreaming(obj);
            end

        end

        function onStopStreamingButtonPushed(obj, ~, ~)
            stopStreaming(obj);
        end

        function onStartStreamingButtonPushed(obj, ~, ~)
            %Start or stop IMU streaming

            if (~obj.Model.StreamingInProgress)
                startStreaming(obj);
            else
                stopStreaming(obj);
            end

        end

        function startStreaming(obj)
            resetSessionData(obj);

            if (obj.Model.startSessionStreaming())
                obj.SessionTabView.StartStreamingButton.Enable = "off";
                obj.SessionTabView.StopStreamingButton.Enable = "on";
                obj.SessionTabView.RecordingButton.Enable = "on";

                doSessionStreaming(obj);
            end
        end

        function stopStreaming(obj)
            obj.Model.stopSessionStreaming()

            obj.SessionTabView.StopStreamingButton.Enable = "off";
            if (obj.Model.bothIMUDevicesConnected() && obj.Model.calibrationCompleted())
                obj.SessionTabView.StartStreamingButton.Enable = "on";
            else
                obj.SessionTabView.StartStreamingButton.Enable = "off";
            end

            obj.SessionTabView.RecordingButton.Enable = "off";
            obj.SessionTabView.RecordingButton.Text = "Start Recording";
        end

        function onRecordingButtonPushed(obj, ~, ~)
            %Stop or start recording data

            if (~obj.Model.RecordingInProgress)
                obj.Model.startRecording();
                resetRecordingData(obj);
                obj.SessionTabView.RecordingButton.Text = "Stop Recording";
            else
                obj.Model.stopRecording();
                obj.SessionTabView.RecordingButton.Text = "Start Recording";
            end

        end

        function doSessionStreaming(obj)
            %Update graphs and values while session is active.

            delay = calculateDelay(obj);

            successThresholdPercent = 50.0;
            numOfAttempts = obj.Model.getPollingRate() * 3;
            attempts = ones(numOfAttempts, 1);
            index = 1;

            timeLastLoop = 0;
            elapsedTime = 0;
            beepTimer = 0;

            %Initialise graph lines
            obj.LumbarAngleLine = animatedline(obj.SessionTabView.LumbarAngleGraph);
            obj.ThresholdLine = animatedline(obj.SessionTabView.LumbarAngleGraph, "Color", "r");
            obj.GradientLine = [];

            while (obj.Model.StreamingInProgress)
                tic; %Start timer

                pause(delay);
                angleRetrievalFailed = false;

                % Stop session if device not streaming
                if (~obj.Model.bothIMUDevicesStreaming)
                    stopStreaming(obj);
                    break
                end

                % Retrieve latest angle, noting failure
                try
                    latestAngle = obj.Model.LatestCalibratedAngle;
                catch
                    angleRetrievalFailed = true;
                    attempts(index) = 0;

                    successes = sum(attempts,'all');

                    successPercentage = round((successes * 100) / numOfAttempts, 2);

                    if (successPercentage < successThresholdPercent)
                        disp("Warning: Aborting session due to high rate of lost packets! (" + successPercentage + "% attempts successful of last " + numOfAttempts + " to read data.)");
                        stopStreaming(obj)
                    end
                end

                if (~angleRetrievalFailed)
                    attempts(index) = 1;
                    drawGraphs(obj, latestAngle, elapsedTime);
                    beepTimer = doThresholdFunctionality(obj, latestAngle, beepTimer, timeLastLoop);
                end

                %Data recording
                if (obj.Model.RecordingInProgress)
                    angleToWrite = latestAngle;
                    if(angleRetrievalFailed)
                        angleToWrite = "?";
                    end
                    
                    obj.Model.FileExportManager.writeAngleData([string(datetime("now")), angleToWrite, obj.Model.ThresholdAngle, (latestAngle > obj.Model.ThresholdAngle)]);
                end

                obj.Model.addTimeStreaming(timeLastLoop);

                updateTimeLabels(obj);

                beepTimer = beepTimer + timeLastLoop;
                elapsedTime = elapsedTime + timeLastLoop;
                timeLastLoop = toc;

                if (index > numOfAttempts)
                    index = 1;
                else
                    index = index + 1;
                end
            end
        end

        function drawGraphs(obj, latestAngle, elapsedTime)
            
            arguments
                obj
                latestAngle double
                elapsedTime double {mustBeNonnegative}
            end

            %Update and draw angle and gradient graphs 
            xAxisTimeDuration = 30;

            updateStoredAngles(obj, latestAngle);

            %Plot lines and data
            addpoints(obj.ThresholdLine, elapsedTime, obj.Model.ThresholdAngle);
            addpoints(obj.LumbarAngleLine, elapsedTime, latestAngle);

            %Redraw gradient line
            if (~isempty(obj.GradientLine))
                delete(obj.GradientLine);
            end

            obj.GradientLine = yline(obj.SessionTabView.IndicatorGraph, latestAngle);

            %Move along x-axis
            if (elapsedTime > xAxisTimeDuration)
                obj.SessionTabView.LumbarAngleGraph.XLim = [(elapsedTime - xAxisTimeDuration) elapsedTime];
            end
        end

        function delay = calculateDelay(obj)
            %Calculate the delay from the lowest sampling
            %rate or polling override

            pollingRate = obj.Model.getPollingRate();

            if (pollingRate <= 0)
                delay = 0.1;
            else
                delay = 1 / pollingRate;
            end

            disp("Polling rate this session: " + pollingRate + "Hz (delay of " + delay + "s between attempts to read data)")
        end

        function updateStoredAngles(obj, latestAngle)
            %Update the smallest and largest angles
            %recorded

            arguments
                obj
                latestAngle double {mustBeNonempty}
            end

            obj.Model.updateCeilingAngles(latestAngle);

            obj.SessionTabView.StreamingSmallestAngleLabel.Text = round(obj.Model.SmallestStreamedAngle, 2) + "°";
            obj.SessionTabView.StreamingLargestAngleLabel.Text = round(obj.Model.LargestStreamedAngle, 2) + "°";

            if (obj.Model.RecordingInProgress)
                obj.SessionTabView.RecordedSmallestAngleLabel.Text = round(obj.Model.SmallestRecordedAngle, 2) + "°";
                obj.SessionTabView.RecordedLargestAngleLabel.Text = round(obj.Model.LargestRecordedAngle, 2) + "°";
            end

        end

        function beepTimer = doThresholdFunctionality(obj, latestAngle, beepTimer, timeLastLoop)
            %Update threshold time and play beep

            arguments
                obj 
                latestAngle double {mustBeNonempty}
                beepTimer double {mustBeNonnegative, mustBeNonempty}
                timeLastLoop double {mustBeNonnegative, mustBeNonempty}
            end

            if (latestAngle > obj.Model.ThresholdAngle)
                obj.Model.addTimeAboveThreshold(timeLastLoop);

                obj.SessionTabView.StreamingTimeAboveThresholdLabel.Text = round(obj.Model.TimeAboveThreshold, 2) + "s";
                if (obj.Model.RecordingInProgress)
                    obj.SessionTabView.RecordedTimeAboveThresholdLabel.Text = round(obj.Model.RecordedTimeAboveThreshold, 2) + "s";
                end

                if (beepTimer > obj.Model.BeepRate && obj.Model.BeepEnabled)
                    obj.Model.playWarningBeep();
                    beepTimer = 0;
                end
            end
        end

        function updateTimeLabels(obj)
            obj.SessionTabView.StreamingTimeLabel.Text = round(obj.Model.TimeStreaming, 2) + "s";
            if (obj.Model.RecordingInProgress)
                obj.SessionTabView.RecordingTimeLabel.Text = round(obj.Model.TimeRecording, 2) + "s";
            end
        end

        function resetSessionData(obj)
            %Reset graph
            cla(obj.SessionTabView.LumbarAngleGraph);
            obj.SessionTabView.LumbarAngleGraph.XLim = [0 30];

            cla(obj.SessionTabView.IndicatorGraph);
            obj.SessionTabView.updateTrafficLightGraph(obj.Model.FullFlexionAngle, obj.Model.DecimalThresholdPercentage);

            %Reset displayed measurements
            obj.SessionTabView.StreamingTimeAboveThresholdLabel.Text = "0s";
            obj.SessionTabView.StreamingSmallestAngleLabel.Text = "No data";
            obj.SessionTabView.StreamingLargestAngleLabel.Text = "No data";
            obj.SessionTabView.StreamingTimeLabel.Text = "0s";

            resetRecordingData(obj);
        end

        function resetRecordingData(obj)
            obj.SessionTabView.RecordedTimeAboveThresholdLabel.Text = "0s";
            obj.SessionTabView.RecordedSmallestAngleLabel.Text = "No data";
            obj.SessionTabView.RecordedLargestAngleLabel.Text = "No data";
            obj.SessionTabView.RecordingTimeLabel.Text = "0s";
        end

        %Beep configuration events
        function onBeepToggled(obj, ~, ~)
            obj.Model.BeepEnabled = obj.SessionTabView.WarningBeepField.BeepCheckbox.Value;
        end

        function onBeepRateChanged(obj, ~, ~)
            obj.Model.BeepRate = obj.SessionTabView.WarningBeepField.RateEditField.Value;
        end

    end % methods ( Access = private )

end % classdef
