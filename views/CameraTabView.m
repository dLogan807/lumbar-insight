classdef CameraTabView < matlab.ui.componentcontainer.ComponentContainer
    %Visualizes the data, responding to any relevant model events.

    properties (Access = private)
        % Listener object used to respond dynamically to controller or component events.
        Listener(:, 1) event.listener

        FontSet logical = false

        YAxisMinimum = -50
        YAxisMaximum = 90
        YAxisTickInterval = 10
    end

    properties
        FontSize double = 12

        %Components
        GridLayout matlab.ui.container.GridLayout
    end

    events (NotifyAccess = private)
        %Event broadcast when view is interacted with


    end % events ( NotifyAccess = private )

    methods

        function obj = CameraTabView(namedArgs)
            %View constructor.

            arguments
                namedArgs.?CameraTabView
            end % arguments

            % Do not create a default figure parent for the component, and
            % ensure that the component spans its parent. By default,
            % ComponentContainer objects are auto-parenting - that is, a
            % figure is created automatically if no parent argument is
            % specified.
            obj@matlab.ui.componentcontainer.ComponentContainer( ...
                "Parent", [], ...
                "Units", "normalized", ...
                "Position", [0, 0, 1, 1])

            % Set any user-specified properties.
            set(obj, namedArgs)

            % Listen for changes in components

        end
    end

    methods (Access = protected)

        function setup(obj)
            %Initialize the view.

            obj.GridLayout = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {22, "1x", 22, 30, 40, 30, 30}, ...
                "ColumnWidth", {"2x", ".5x", "1x"}, ...
                "Padding", 20, ...
                "ColumnSpacing", 40);

            
            
        end

        function update(obj)

            if (~obj.FontSet)
                set(findall(obj.GridLayout, '-property', 'FontSize'), 'FontSize', obj.FontSize);
                obj.FontSet = true;
            end

        end

    end

    methods (Access = private)

    end

end
