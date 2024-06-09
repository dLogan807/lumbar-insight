classdef ShimmerTabView < matlab.ui.componentcontainer.ComponentContainer 
    %VIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )         
        % Line object used to visualize the model data.
        Line(1, 1) matlab.graphics.primitive.Line
        % Application data model.
        Model(1, 1) Model
        % Listener object used to respond dynamically to model events.
        Listener(:, 1) event.listener {mustBeScalarOrEmpty}
    end

    events ( NotifyAccess = private )
        % Event broadcast when view is interacted with
        ButtonPressed


    end % events ( NotifyAccess = private )

    methods

        function obj = ShimmerTabView( model, namedArgs ) 
            %VIEW View constructor.

            arguments
                model(1, 1) Model
                namedArgs.?ShimmerTabView 
            end % arguments

            % Do not create a default figure parent for the component, and
            % ensure that the component spans its parent. By default,
            % ComponentContainer objects are auto-parenting - that is, a
            % figure is created automatically if no parent argument is
            % specified.
            obj@matlab.ui.componentcontainer.ComponentContainer( ... 
                "Parent", [], ... 
                "Units", "normalized", ... 
                "Position", [0, 0, 1, 1] ) 

            % Store the model.
            obj.Model = model; 

            % Listen for changes to the data. 
            obj.Listener = listener( obj.Model, ... 
                "ShimmerConnected", @obj.onShimmerConnected ); 

            % Set any user-specified properties.
            set( obj, namedArgs ) 

            % Refresh the view. 
            onShimmerConnected( obj ) 

        end 

    end 

    methods ( Access = protected ) 

        function setup( obj ) 
            %SETUP Initialize the view. 

            % Create the view graphics. 
            ax = axes( "Parent", obj ); 
            obj.Line = line( ... 
                "Parent", ax, ... 
                "XData", NaN, ... 
                "YData", NaN, ... 
                "Color", ax.ColorOrder(1, :), ... 
                "LineWidth", 1.5 ); 

        end

        function update( ~ ) 
            %UPDATE Update the view. This method is empty because there are 
            %no public properties of the view. 

        end

    end

    methods ( Access = private ) 

        function onShimmerConnected( obj, ~, ~ ) 
            %ONDATACHANGED Listener callback, responding to the model event
            %"DataChanged"
        end

    end

end