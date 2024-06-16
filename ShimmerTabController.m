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
        Listener(:, 1) event.listener
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

            % Listen for changes to the view. 
            obj.Listener(end+1) = listener( obj.ShimmerTabView, ... 
                "ScanButtonPushed", @obj.onScanButtonPushed );

            % Listen for changes to the model data.
            obj.Listener(end+1) = listener( obj.Model, ... 
                "DeviceListUpdated", @obj.onDeviceListUpdated );
            
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
            disp("Scanning!")
            %ONSCANBUTTONPUSHED Listener callback, responding to the view event

            % Retrieve Shimmer bluetooth devices and update the model.
            obj.ShimmerTabView.SetBTScanButtonState("Scanning");

            allDevices = bluetoothlist;
            TF = contains(allDevices.Name, "Shimmer3");

            shimmers = allDevices(TF,:);
            shimmers.Address = [];
            shimmers.Channel = [];
            shimmers = convertvars(shimmers,{'Name','Status'},'string');
            % shimmers.Status = statusLinkToString(shimmers.Status);

            obj.Model.BluetoothDevices = shimmers;
        end

        function onDeviceListUpdated( obj, ~, ~ )
            setBTDeviceListData(obj.Model.BluetoothDevices);
            disp(obj.Model.BluetoothDevices);
        end

        function shimmerStatus = statusLinkToString( htmlElement )
            
            startIndex = strfind(htmlElement, "''>");
            endIndex = strfind(htmlElement, "</a>");

            shimmerStatus = extractBetween(htmlElement, startIndex, endIndex);
        end
    end % methods ( Access = private )
    
end % classdef