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

    end % methods ( Access = private )
    
end % classdef