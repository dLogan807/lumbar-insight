classdef LumbarInsight < Singleton
   properties % Public Access
      Figure (1, 1) matlab.ui.Figure = uifigure( ...
                    "Name", "Lumbar Insight", ...
                    "Position", [50 100 900 500], ...
                    "WindowState", "maximized" );
   end
   
   methods(Access=private)
      % Guard the constructor against external invocation.  We only want
      % to allow a single instance of this class.  See description in
      % Singleton superclass.
      function newObj = LumbarInsight()
          if (~isvalid(newObj.Figure))
            createFigure(newObj)
          end
          launchLumbarInsight(newObj);
      end
   end
   
   methods(Static)
      % Concrete implementation.  See Singleton superclass.
      function obj = instance()
         persistent uniqueInstance
         if isempty(uniqueInstance)
            % No instance of app
            obj = LumbarInsight();
            uniqueInstance = obj;
         else
            % App instance exists
            obj = uniqueInstance;
            if (~isvalid(obj.Figure))
                % Previous figure handle was deleted
                createFigure(obj);
                launchLumbarInsight( obj );
            end
         end
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
            model = Model;
            
            %Create the views
            fontSize = 16;
            
            imuTabView = IMUTabView( "Parent", imuTab, ...
                "FontSize", fontSize );
            sessionTabView = SessionTabView( "Parent", sessionTab, ...
                "FontSize", fontSize );
            
            %Create the controllers
            imuTabController = IMUTabController( model, imuTabView );
            SessionTabController( imuTabController.Model, sessionTabView);
        
        end
   end
   
end
