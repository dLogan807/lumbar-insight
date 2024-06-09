classdef ShimmerTabController < handle
    %CONTROLLER Provides an interactive control to generate new data.
    %
    % Copyright 2021-2022 The MathWorks, Inc.

    properties ( Access = private )
        % Application data model.
        Model(1, 1) Model
        % Shimmer View
        ShimmerTabView ShimmerTabView
        % Listener object used to respond dynamically to view events.
        Listener(:, 1) event.listener {mustBeScalarOrEmpty}
    end % properties ( Access = private )
    
    methods
        
        function obj = ShimmerTabController( model, shimmerTabView )
            % CONTROLLER Controller constructor.
            
            arguments
                model(1, 1) Model
                shimmerTabView ShimmerTabView
            end % arguments

            % Store the model.
            obj.Model = model;

            obj.ShimmerTabView = shimmerTabView;

            % Listen for changes to the data. 
            obj.Listener = listener( obj.ShimmerTabView, ... 
                "ScanButtonPushed", @obj.onScanButtonPushed ); 
            
        end % constructor
        
    end % methods
    
    methods ( Access = protected )
        
        function setup( obj )
            %SETUP Initialize the controller.
            
            
        end % setup
        
        function update( ~ )
            %UPDATE Update the controller. This method is empty because 
            %there are no public properties of the controller.
            
        end % update
        
    end % methods ( Access = protected )
    
    methods ( Access = private )
        function onScanButtonPushed( obj, ~, ~ ) 
            %ONSCANBUTTONPUSHED Listener callback, responding to the view event

            % Retrieve Shimmer bluetooth devices and update the model.
            allDevices = bluetoothlist;
            TF = contains(allDevices.Name, "Shimmer3");

            shimmers = allDevices(TF,:);
            shimmers.Address = [];
            shimmers.Channel = [];
            % shimmers = convertvars(shimmers,{'Name','Status'},'string');
            shimmers.Name = extractHTMLText(shimmers.Name);

            obj.Model.BluetoothDevices = shimmers;
        end
        
    end % methods ( Access = private )
    
end % classdef