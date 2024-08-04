classdef SessionTabController < handle
    %IMUTABCONTROLLER Provides an interactive control to generate new data.

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
            % CONTROLLER Controller constructor.
            
            arguments
                model(1, 1) Model
                sessionTabView SessionTabView
            end % arguments

            % Store the model.
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
            %SETUP Initialize the controller.
            
        end % setup
        
        function update( ~ )
            %UPDATE Update the controller. This method is empty because 
            %there are no public properties of the controller.
            
        end % update
        
    end % methods ( Access = protected )
    
    methods ( Access = private )

        function onDevicesConnectedChanged( obj, ~, ~ )
            handleSessionControls( obj );
        end

        function onStandingOffsetAngleCalibrated( obj ,~, ~ )
            handleSessionControls( obj );
        end

        function onFullFlexionAngleCalibrated( obj ,~, ~ )
            handleSessionControls( obj );
        end

        function handleSessionControls( obj )
            %HANDLESESSION Enable session control buttons depending on
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
        end

        function onSessionStartButtonPushed( obj, ~, ~ )
            obj.SessionTabView.SessionStartButton.Enable = "off";
            obj.SessionTabView.SessionStopButton.Enable = "on";

            obj.Model.startSession;

            cla(obj.SessionTabView.LumbarAngleGraph);
            resetSessionData( obj );

            delay = calculateDelay( obj );
            xDuration = 30;

            elapsedTime = 0;
            tic; % Start timer

            lumbarAngleLine = animatedline(obj.SessionTabView.LumbarAngleGraph);
            thresholdLine = animatedline(obj.SessionTabView.LumbarAngleGraph, "Color", "r");

            while ( obj.Model.SessionInProgress )
                if (~obj.Model.bothIMUDevicesConnected)
                    obj.Model.stopSession;
                    break
                end

                pause(delay);

                try
                    latestAngle = obj.Model.LatestCalibratedAngle;
                catch
                    continue
                end

                updateCeilingAngles( obj, latestAngle );

                % Plot lines
                addpoints(lumbarAngleLine, elapsedTime, latestAngle);

                thresholdAngle = (obj.Model.FullFlexionAngle * obj.Model.ThresholdAnglePercentage);
                addpoints(thresholdLine, elapsedTime, thresholdAngle);

                % Move along x-axis
                if (elapsedTime > xDuration)
                    obj.SessionTabView.LumbarAngleGraph.XLim = [(elapsedTime - xDuration) elapsedTime];
                end

                if (latestAngle > thresholdAngle)
                    obj.Model.timeAboveThresholdAngle = obj.Model.timeAboveThresholdAngle + toc;

                    obj.SessionTabView.TimeAboveMaxLabel.Text = "Time above threshold angle: " + obj.Model.timeAboveThresholdAngle + "s";
                end

                elapsedTime = elapsedTime + toc;                                                              % Stop timer and add to elapsed time
                tic;
            end

            obj.SessionTabView.SessionStartButton.Enable = "on";
        end

        function delay = calculateDelay( obj)
            %CALCULATEDELAY Calculate the delay from the lowest sampling
            %rate

            samplingRate = obj.Model.lowestSamplingRate;

            if (samplingRate <= 0)
                delay = 0.1;
            else
                delay = 1 / samplingRate;
            end
        end

        function updateCeilingAngles( obj, latestAngle )
            if (obj.Model.SmallestAngle == -1 || latestAngle < obj.Model.SmallestAngle)
                obj.Model.SmallestAngle = latestAngle;
                obj.SessionTabView.SmallestAngleLabel.Text = "Smallest Angle: " + latestAngle + "°";
            end

            if (obj.Model.LargestAngle == -1 || latestAngle > obj.Model.LargestAngle)
                obj.Model.LargestAngle = latestAngle;
                obj.SessionTabView.LargestAngleLabel.Text = "Largest Angle: " + latestAngle + "°";
            end
        end

        function resetSessionData( obj )
            obj.SessionTabView.SmallestAngleLabel.Text = "Smallest Angle: No data";
            obj.SessionTabView.LargestAngleLabel.Text = "Largest Angle: No data";
            obj.SessionTabView.TimeAboveMaxLabel.Text = "Time above threshold angle: 0s";
        end

        function onSessionStopButtonPushed( obj, ~, ~ )
            obj.Model.stopSession;
            obj.SessionTabView.SessionStopButton.Enable = "off";
        end

    end % methods ( Access = private )
    
end % classdef