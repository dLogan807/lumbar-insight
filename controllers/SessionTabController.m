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

        function onThresholdSliderValueChanged( obj, ~, ~ )
            obj.Model.ThresholdAnglePercentage = obj.SessionTabView.AngleThresholdSlider.Value;
            disp("Model: " + obj.Model.ThresholdAnglePercentage);
        end

        function onSessionStartButtonPushed( obj, ~, ~ )
            obj.SessionTabView.SessionStartButton.Enable = "off";
            obj.SessionTabView.SessionStopButton.Enable = "on";
            obj.Model.SessionInProgress = true;

            cla(obj.SessionTabView.LumbarAngleGraph);

            delay = 0.1;
            xDuration = 30;

            elapsedTime = 0;
            tic; % Start timer

            lumbarAngleLine = animatedline(obj.SessionTabView.LumbarAngleGraph);
            thresholdLine = animatedline(obj.SessionTabView.LumbarAngleGraph, "Color", "r");

            while ( obj.Model.SessionInProgress )
                pause(delay);

                latestAngle = obj.Model.LatestAngle;

                if (obj.Model.SmallestAngle == -1 || latestAngle < obj.Model.SmallestAngle)
                    obj.Model.SmallestAngle = latestAngle;
                    obj.SessionTabView.SmallestAngleLabel.Text = "Smallest Angle: " + latestAngle + "°";
                end

                if (obj.Model.LargestAngle == -1 || latestAngle > obj.Model.LargestAngle)
                    obj.Model.LargestAngle = latestAngle;
                    obj.SessionTabView.LargestAngleLabel.Text = "Largest Angle: " + latestAngle + "°";
                end

                addpoints(lumbarAngleLine, elapsedTime, latestAngle);
                addpoints(thresholdLine, elapsedTime, (obj.Model.FullFlexionAngle * obj.Model.ThresholdAnglePercentage));

                if (elapsedTime > xDuration)
                    obj.SessionTabView.LumbarAngleGraph.XLim = [(elapsedTime - xDuration) elapsedTime];
                end

                drawnow;

                elapsedTime = elapsedTime + toc;                                                              % Stop timer and add to elapsed time
                tic;
            end

            obj.SessionTabView.SessionStartButton.Enable = "on";
        end

        function onSessionStopButtonPushed( obj, ~, ~ )
            obj.Model.SessionInProgress = false;
            obj.SessionTabView.SessionStopButton.Enable = "off";
        end

    end % methods ( Access = private )
    
end % classdef