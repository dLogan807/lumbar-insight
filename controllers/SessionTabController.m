classdef SessionTabController < handle
    %Provides an interactive control to generate new data.

    properties (Access = private)
        % Application data model.
        Model(1, 1) Model
        % IMU View
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
                "ThresholdSliderValueChanged", @obj.onThresholdSliderValueChanged);
            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "StreamingButtonPushed", @obj.onStreamingButtonPushed);
            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "RecordingButtonPushed", @obj.onRecordingButtonPushed);

            obj.Listener(end + 1) = listener(obj.SessionTabView, ...
                "StopButtonPushed", @obj.onStopButtonPushed);

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
            updateSessionControls(obj);
        end

        function onStandingOffsetAngleCalibrated(obj, ~, ~)
            updateSessionControls(obj);
        end

        function onFullFlexionAngleCalibrated(obj, ~, ~)
            updateSessionControls(obj);
            updateThresholdData(obj)
        end

        function onThresholdSliderValueChanged(obj, ~, ~)
            if (obj.Model.calibrationCompleted())
                updateThresholdData(obj);
            end
        end

        function updateThresholdData(obj)
            %Update data and graphs relating to the threshold angle

            wholePercentageValue = round(obj.SessionTabView.AngleThresholdSlider.Value);
            obj.Model.DecimalThresholdPercentage = wholePercentageValue;
            obj.Model.ThresholdAngle = obj.Model.FullFlexionAngle * obj.Model.DecimalThresholdPercentage;

            obj.SessionTabView.updateTrafficLightGraph(obj.Model.FullFlexionAngle, obj.Model.DecimalThresholdPercentage);
            obj.SessionTabView.setThresholdLabelPercentage(wholePercentageValue);
        end

        function updateSessionControls(obj)
            %Enable session control buttons depending on
            %angle calibration

            obj.SessionTabView.StreamingButton.Enable = "off";

            if (obj.Model.bothIMUDevicesConnected && obj.Model.calibrationCompleted())
                obj.SessionTabView.StreamingButton.Enable = "on";
            else
                stopStreaming(obj);
            end

        end

        function onStopButtonPushed(obj ,~, ~)
            stopStreaming(obj);
        end

        function onStreamingButtonPushed(obj, ~, ~)
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
                obj.SessionTabView.StreamingButton.Text = "Stop IMU Streaming";
                obj.SessionTabView.RecordingButton.Enable = "on";

                doSessionStreaming(obj);
            end

        end

        function stopStreaming(obj)
            obj.Model.stopSessionStreaming()
            obj.SessionTabView.StreamingButton.Text = "Start IMU Streaming";

            obj.SessionTabView.RecordingButton.Enable = "off";
            obj.SessionTabView.RecordingButton.Text = "Start Recording";
        end

        function onRecordingButtonPushed(obj, ~, ~)
            %Stop or start recording data

            if (~obj.Model.RecordingInProgress)
                obj.Model.startRecording();
                obj.SessionTabView.RecordingButton.Text = "Stop Recording";
            else
                obj.Model.stopRecording();
                obj.SessionTabView.RecordingButton.Text = "Start Recording";
            end

        end

        function doSessionStreaming(obj)
            %Update graphs and values while session is active.

            delay = calculateDelay(obj);

            failures = 0;
            totalAttempts = 0;
            failureThresholdPercent = 40.0;
            failurePercentage = 0.0;

            elapsedTime = 0;
            beepTimer = 0;
            tic; %Start timer

            %Initialise graph lines
            obj.LumbarAngleLine = animatedline(obj.SessionTabView.LumbarAngleGraph);
            obj.ThresholdLine = animatedline(obj.SessionTabView.LumbarAngleGraph, "Color", "r");
            obj.GradientLine = [];

            while (obj.Model.StreamingInProgress)
                pause(delay);
                totalAttempts = totalAttempts + 1;
                angleRetrievalFailed = false;

                % Stop session if device not streaming
                if (~obj.Model.bothIMUDevicesStreaming)
                    stopStreaming(obj);
                    break
                end

                % Retrieve latest angle, recording failure
                try
                    latestAngle = obj.Model.LatestCalibratedAngle;
                catch
                    failures = failures + 1;

                    failurePercentage = round((failures * 100) / totalAttempts, 2);

                    if (failurePercentage > failureThresholdPercent)
                        disp("Warning: Aborting session due to high rate of lost packets!")
                        stopStreaming(obj)
                    end

                    angleRetrievalFailed = true;
                end

                if (~angleRetrievalFailed)
                    drawGraphs(obj, latestAngle, elapsedTime);
                end

                %Timing
                timeThisLoop = toc;

                overThresholdAngle = (latestAngle > obj.Model.ThresholdAngle);
                if (overThresholdAngle)
                    obj.Model.TimeAboveThresholdAngle = obj.Model.TimeAboveThresholdAngle + round(timeThisLoop, 2);
                    obj.SessionTabView.TimeAboveMaxLabel.Text = "Time above threshold angle: " + obj.Model.TimeAboveThresholdAngle + "s";

                    if (beepTimer > obj.Model.BeepRate && obj.Model.BeepEnabled)
                        obj.Model.playWarningBeep();
                        beepTimer = 0;
                    end

                end

                beepTimer = beepTimer + timeThisLoop;
                elapsedTime = elapsedTime + timeThisLoop;
                if (obj.Model.RecordingInProgress)
                    obj.Model.TimeRecording = obj.Model.TimeRecording + timeThisLoop;
                    
                    angleToWrite = latestAngle;
                    if(angleRetrievalFailed)
                        angleToWrite = "?";
                    end
                    
                    obj.Model.FileExportManager.writeAngleData([string(datetime("now")), angleToWrite, obj.Model.ThresholdAngle, overThresholdAngle]);
                end
                tic;
            end

            disp("Failure rate: " + failurePercentage + "% (" + failures + " failures out of " + totalAttempts + " read attempts)");
        end

        function drawGraphs(obj, latestAngle, elapsedTime)
            
            arguments
                obj
                latestAngle double
                elapsedTime double
            end

            %Update and draw angle and gradient graphs 
            xAxisTimeDuration = 30;

            updateCeilingAngles(obj, latestAngle);

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

            if (obj.Model.PollingOverrideEnabled)
                pollingRate = obj.Model.PollingRateOverride;
            else
                pollingRate = obj.Model.lowestSamplingRate;
            end

            if (pollingRate <= 0)
                delay = 0.1;
            else
                delay = 1 / pollingRate;
            end

            disp("Polling rate this session: " + pollingRate + "Hz (delay of " + delay + "s between read attempts)")
        end

        function updateCeilingAngles(obj, latestAngle)
            %Update the smallest and largest angles
            %recorded

            arguments
                obj
                latestAngle double {mustBeNonempty}
            end

            round(latestAngle, 2);

            if (isempty(obj.Model.SmallestAngle) || latestAngle < obj.Model.SmallestAngle)
                obj.Model.SmallestAngle = latestAngle;
                obj.SessionTabView.SmallestAngleLabel.Text = "Smallest Angle: " + latestAngle + "°";
            end

            if (isempty(obj.Model.LargestAngle) || latestAngle > obj.Model.LargestAngle)
                obj.Model.LargestAngle = latestAngle;
                obj.SessionTabView.LargestAngleLabel.Text = "Largest Angle: " + latestAngle + "°";
            end

        end

        function resetSessionData(obj)
            %Reset graph
            cla(obj.SessionTabView.LumbarAngleGraph);
            obj.SessionTabView.LumbarAngleGraph.XLim = [0 30];

            cla(obj.SessionTabView.IndicatorGraph);
            obj.SessionTabView.updateTrafficLightGraph(obj.Model.FullFlexionAngle, obj.Model.DecimalThresholdPercentage);

            %Reset measurements
            obj.SessionTabView.SmallestAngleLabel.Text = "Smallest angle: No data";
            obj.SessionTabView.LargestAngleLabel.Text = "Largest angle: No data";
            obj.SessionTabView.TimeAboveMaxLabel.Text = "Time above threshold angle: 0s";

            %Reset data
            obj.Model.TimeAboveThresholdAngle = 0;
            obj.Model.TimeRecording = 0;
            obj.Model.SmallestAngle = [];
            obj.Model.LargestAngle = [];
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
