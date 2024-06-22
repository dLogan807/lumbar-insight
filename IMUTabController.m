classdef IMUTabController < handle
    %IMUTABCONTROLLER Provides an interactive control to generate new data.

    properties ( Access = private )
        % Application data model.
        Model(1, 1) Model
        % IMU View
        IMUTabView IMUTabView
        % Listener object used to respond dynamically to view events.
        Listener(:, 1) event.listener
    end % properties ( Access = private )
    
    methods
        
        function obj = IMUTabController( model, imuTabView )
            % CONTROLLER Controller constructor.
            
            arguments
                model(1, 1) Model
                imuTabView IMUTabView
            end % arguments

            % Store the model.
            obj.Model = model;

            obj.IMUTabView = imuTabView;

            % Listen for changes to the view. 
            obj.Listener(end+1) = listener( obj.IMUTabView, ... 
                "BTScanButtonPushed", @obj.onBTScanButtonPushed );

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
        function onBTScanButtonPushed( obj, ~, ~ ) 
            % ONBTSCANBUTTONPUSHED Listener callback, responding to the view event

            % Retrieve bluetooth devices and update the model.
            obj.IMUTabView.SetBTScanButtonState("Scanning");

            allDevices = bluetoothlist("Timeout", 10);
            allDevices.Address = [];
            allDevices.Channel = [];
            allDevices = convertvars(allDevices,{'Name','Status'},'string');

            allDevices = statusHTMLToText(obj, allDevices);

            obj.Model.BluetoothDevices = allDevices;
        end

        function onDeviceListUpdated( obj, ~, ~ )
            obj.IMUTabView.setBTDeviceListData(obj.Model.BluetoothDevices);
            obj.IMUTabView.SetBTScanButtonState("Devices Retrieved");
        end

        function formattedDevices = statusHTMLToText( ~, deviceTable )
            %ONDEVICELISTUPDATED Convert any HTML <a> elements to plaintext
            
            rows = height(deviceTable);
            for row = 1:rows
                currentRow = deviceTable.Status(row,:);

                startIndex = strfind(currentRow, ">");
                if (isempty(startIndex))
                    continue;
                end
                endIndex = strfind(currentRow, "</");

                deviceTable.Status(row,:) = extractBetween(currentRow, startIndex(1) + 1, endIndex(1) - 1);
            end

            formattedDevices = deviceTable;
        end
    end % methods ( Access = private )
    
end % classdef