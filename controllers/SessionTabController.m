classdef SessionTabController < handle
    %Provides an interactive control to generate new data.

    properties ( Access = private )
        % Application data model.
        Model(1, 1) Model
        % IMU View
        SessionTabView SessionTabView
        % Listener object used to respond dynamically to view events.
        Listener(:, 1) event.listener
    end % properties ( Access = private )
    
    methods
        
        function obj = SessionTabController( model, sessionTabView )
            %Controller constructor.
            
            arguments
                model(1, 1) Model
                sessionTabView SessionTabView
            end % arguments

            % Store the model and view
            obj.Model = model;
            obj.SessionTabView = sessionTabView;

            % Listen for changes to the view. 
            obj.Listener(end+1) = listener( obj.SessionTabView, ... 
                "ThresholdSliderValueChanged", @obj.onThresholdSliderValueChanged );
            obj.Listener(end+1) = listener( obj.SessionTabView, ... 
                "SessionStartButtonPushed", @obj.onSessionStartButtonPushed );
            obj.Listener(end+1) = listener( obj.SessionTabView, ... 
                "SessionStopButtonPushed", @obj.onSessionStopButtonPushed );

            % Listen for changes to the model data.
            obj.Listener(end+1) = listener( obj.Model, ...
                "DevicesConnectedChanged", @obj.onDevicesConnectedChanged );
            obj.Listener(end+1) = listener( obj.Model, ...
                "StandingOffsetAngleCalibrated", @obj.onStandingOffsetAngleCalibrated );
            obj.Listener(end+1) = listener( obj.Model, ...
                "FullFlexionAngleCalibrated", @obj.onFullFlexionAngleCalibrated );
            
        end % constructor
        
    end % methods
    
    methods ( Access = protected )
        
        function setup( ~ )
            %Initialize the controller.
            
        end % setup
        
        function update( ~ )
            %Update the controller. This method is empty because 
            %there are no public properties of the controller.
            
        end % update
        
    end % methods ( Access = protected )
    
    methods ( Access = private )

        function onDevicesConnectedChanged( obj, ~, ~ )
            updateSessionControls( obj );
        end

        function onStandingOffsetAngleCalibrated( obj, ~, ~ )
            updateSessionControls( obj );
        end

        function onFullFlexionAngleCalibrated( obj, ~, ~ )
            updateSessionControls( obj );
            obj.SessionTabView.FullFlexionAngle = obj.Model.FullFlexionAngle;
        end

        function updateSessionControls( obj )
            %Enable session control buttons depending on
            %angle calibration

            obj.SessionTabView.SessionStopButton.Enable = "off";

            if (obj.Model.bothIMUDevicesConnected && obj.Model.calibrationCompleted)
                obj.SessionTabView.SessionStartButton.Enable = "on";
            else
                obj.SessionTabView.SessionStartButton.Enable = "off";
                if (obj.Model.SessionInProgress)
                    obj.Model.stopSession;
                end
            end
        end

        function onThresholdSliderValueChanged( obj, ~, ~ )
            obj.Model.ThresholdAnglePercentage = obj.SessionTabView.AngleThresholdSlider.Value;
            obj.SessionTabView.ThresholdPercentage = obj.Model.ThresholdAnglePercentage;
        end

        function onSessionStartButtonPushed( obj, ~, ~ )
            %Update graphs and values while session is active.

            obj.SessionTabView.SessionStartButton.Enable = "off";
            obj.SessionTabView.SessionStopButton.Enable = "on";
            obj.Model.ThresholdAnglePercentage = obj.SessionTabView.AngleThresholdSlider.Value;

            obj.Model.startSession;

            resetSessionData( obj );

            delay = calculateDelay( obj );
            xAxisTimeDuration = 30;
            failures = 0;
            totalAttempts = 0;
            failureThresholdPercent = 25.0;
            failurePercentage = 0.0;

            elapsedTime = 0;
            tic; %Start timer

            lumbarAngleLine = animatedline(obj.SessionTabView.LumbarAngleGraph);
            latestAngleText = text(obj.SessionTabView.LumbarAngleGraph, 2, 85, "Angle:");
            latestAngleText.FontSize = 16;
            thresholdLine = animatedline(obj.SessionTabView.LumbarAngleGraph, "Color", "r");

            gradientLine = [];

            while ( obj.Model.SessionInProgress )
                pause(delay);
                totalAttempts = totalAttempts + 1;
                angleRetrievalFailed = false;

                % Stop session if device not streaming
                if (~obj.Model.bothIMUDevicesStreaming)
                    obj.Model.stopSession;
                    break
                end

                try
                    latestAngle = obj.Model.LatestCalibratedAngle;
                catch
                    failures = failures + 1;

                    failurePercentage = round((failures * 100) / totalAttempts, 2);

                    if (failurePercentage > failureThresholdPercent)
                        disp("Warning: Aborting session due to high rate of lost packets!")
                        obj.Model.stopSession;
                    end
                    
                    angleRetrievalFailed = true;
                end

                if (~angleRetrievalFailed)
                    updateCeilingAngles( obj, latestAngle );
    
                    %Plot lines and data
                    addpoints(lumbarAngleLine, elapsedTime, latestAngle);
                    latestAngleText.String = "Angle: " + round(latestAngle, 2) + "°";
    
                    thresholdAngle = (obj.Model.FullFlexionAngle * obj.Model.ThresholdAnglePercentage);
                    addpoints(thresholdLine, elapsedTime, thresholdAngle);
    
                    %Redraw gradient line
                    if (~isempty(gradientLine))
                        delete(gradientLine);
                    end
                    gradientLine = yline(obj.SessionTabView.IndicatorGraph, latestAngle);
    
                    %Move along x-axis
                    if (elapsedTime > xAxisTimeDuration)
                        obj.SessionTabView.LumbarAngleGraph.XLim = [(elapsedTime - xAxisTimeDuration) elapsedTime];
                        latestAngleText.Position = [(elapsedTime - xAxisTimeDuration + 2) 85];
                    end
                end

                %Timing
                timeThisLoop = toc;
                if (latestAngle > thresholdAngle)
                    obj.Model.timeAboveThresholdAngle = obj.Model.timeAboveThresholdAngle + timeThisLoop;
                    obj.SessionTabView.TimeAboveMaxLabel.Text = "Time above threshold angle: " + round(obj.Model.timeAboveThresholdAngle, 2) + "s";
                end
                
                elapsedTime = elapsedTime + timeThisLoop;
                tic;
            end

            disp("Failure rate: " + failurePercentage + "% (" + failures + " failures out of " + totalAttempts + " read attempts)");
            updateSessionControls( obj );
        end

        function delay = calculateDelay( obj)
            %Calculate the delay from the lowest sampling
            %rate or polling override

            if (obj.Model.PollingOverrideEnabled)
                samplingRate = obj.Model.PollingRateOverride;
            else
                samplingRate = obj.Model.lowestSamplingRate;
            end


            if (samplingRate <= 0)
                delay = 0.1;
            else
                delay = 1 / samplingRate;
            end

            disp("Sampling rate this session: " + samplingRate + " (delay of " + delay + " between read attempts)")
        end

        function updateCeilingAngles( obj, latestAngle )
            %Update the smallest and largest angles
            %recorded

            arguments
                obj 
                latestAngle double {mustBeNonempty}
            end

            if (isempty(obj.Model.SmallestAngle) || latestAngle < obj.Model.SmallestAngle)
                obj.Model.SmallestAngle = latestAngle;
                obj.SessionTabView.SmallestAngleLabel.Text = "Smallest Angle: " + round(latestAngle, 2) + "°";
            end

            if (isempty(obj.Model.LargestAngle) || latestAngle > obj.Model.LargestAngle)
                obj.Model.LargestAngle = latestAngle;
                obj.SessionTabView.LargestAngleLabel.Text = "Largest Angle: " + round(latestAngle, 2) + "°";
            end
        end

        function resetSessionData( obj )
            %Reset graph
            cla(obj.SessionTabView.LumbarAngleGraph);
            obj.SessionTabView.LumbarAngleGraph.XLim = [0 30];

            cla(obj.SessionTabView.IndicatorGraph);

            %Reset measurements
            obj.SessionTabView.SmallestAngleLabel.Text = "Smallest Angle: No data";
            obj.SessionTabView.LargestAngleLabel.Text = "Largest Angle: No data";
            obj.SessionTabView.TimeAboveMaxLabel.Text = "Time above threshold angle: 0s";

            %Reset data
            obj.Model.timeAboveThresholdAngle = 0;
            obj.Model.SmallestAngle = [];
            obj.Model.LargestAngle = [];
        end

        function onSessionStopButtonPushed( obj, ~, ~ )
            obj.Model.stopSession;
            obj.SessionTabView.SessionStopButton.Enable = "off";
        end

    end % methods ( Access = private )
    
end % classdef