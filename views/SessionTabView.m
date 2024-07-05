classdef SessionTabView < matlab.ui.componentcontainer.ComponentContainer
    %IMUTABVIEW Visualizes the data, responding to any relevant model events.

    properties ( Access = private )
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        %Components
        
    end

    properties

    end

    events ( NotifyAccess = private )
        % Event broadcast when view is interacted with

    end % events ( NotifyAccess = private )

    methods

        function obj = SessionTabView( namedArgs )
            %VIEW View constructor.

            arguments
                namedArgs.?SessionTabView
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

            % Set any user-specified properties.
            set( obj, namedArgs )

            % Listen for changes in components

        end
    end

    methods ( Access = protected )

        function setup( obj )
            %SETUP Initialize the view.

            gridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {22, 22, 22, 22, 35, 35, "1x", 22, 35, 35}, ...
                "ColumnWidth", {"1x", "1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 50 );

            % Create view components.
            
        end

        function update( ~ )
        end

    end

    methods ( Access = private )


    end

end