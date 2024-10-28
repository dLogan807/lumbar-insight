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


            % Listen for changes to the model data.


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

        
    end % methods ( Access = private )

end % classdef
