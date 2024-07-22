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
            %ONDEVICESCONNECTEDCHANGED Enable start button depending on
            %devices connected.

            if (obj.Model.bothIMUDevicesConnected)
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

            delay = 0.1;
            xDuration = 30;

            elapsedTime = 0;
            tic; % Start timer

            lumbarAngleLine = animatedline(obj.SessionTabView.LumbarAngleGraph);
            thresholdLine = animatedline(obj.SessionTabView.LumbarAngleGraph, "Color", "r");

            while ( obj.Model.SessionInProgress )
                pause(delay);

                latestAngle = obj.Model.LatestAngle;

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