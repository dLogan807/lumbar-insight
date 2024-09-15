classdef NonSingletonLumbarInsight < handle
    %Singleton class to launch the application

    properties % Public Access
        Figure (1, 1) matlab.ui.Figure = uifigure( ...
            "Name", "Lumbar Insight", ...
            "Position", [50 100 900 500], ...
            "WindowState", "maximized" );
        
        AppIMUTabController
        AppSessionTabController
        AppModel
    end
   
    methods
        function newObj = NonSingletonLumbarInsight()
            if (~isvalid(newObj.Figure))
                createFigure(newObj);
            end
            launchLumbarInsight(newObj);
        end
    end
   
    methods (Access = private)

        function createFigure(obj)
            obj.Figure = uifigure( ...
                    "Name", "Lumbar Insight", ...
                    "Position", [50 100 900 500], ...
                    "WindowState", "maximized" );
        end

        %Launch the application.
        function launchLumbarInsight( obj )
            
            %Create tab group
            tabgroup = uitabgroup("Parent", obj.Figure, ...
                "Units", "normalized", ...
                "Position", [0 0 1 1] );
            imuTab = uitab(tabgroup,"Title","IMU Configuration");
            % cameraTab = uitab(tabgroup,"Title","Camera Configuration");
            sessionTab = uitab(tabgroup,"Title","Session");
            % managementTab = uitab(tabgroup,"Title","Session Management");
            
            %Create the model
            obj.AppModel = Model;

            %Create the views
            fontSize = 16;

            imuTabView = IMUTabView( "Parent", imuTab, ...
                "FontSize", fontSize );
            sessionTabView = SessionTabView( "Parent", sessionTab, ...
                "FontSize", fontSize );
            
            %Create the controllers
            obj.AppIMUTabController = IMUTabController( obj.AppModel, imuTabView );
            obj.AppSessionTabController = SessionTabController( obj.AppModel, sessionTabView );
        end
   end
   
end
