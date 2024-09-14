function varargout = launchLumbarInsight( f )
%LAUNCHLUMBARINSIGHT Launch the application.

arguments
% Create figure
    f(1, 1) matlab.ui.Figure = uifigure( ...
        "Name", "Lumbar Insight", ...
        "Position", [50 100 900 500], ...
        "WindowState", "maximized" );
end % arguments

% Create tab group
tabgroup = uitabgroup("Parent", f, ...
    "Units", "normalized", ...
    "Position", [0 0 1 1], ...
    "SelectionChangedFcn", @onTabChanged);
imuTab = uitab(tabgroup,"Title","IMU Configuration");
cameraTab = uitab(tabgroup,"Title","Camera Configuration");
sessionTab = uitab(tabgroup,"Title","Session");
managementTab = uitab(tabgroup,"Title","Session Management");

% Create the model
model = Model;

% Create the views
fontSize = 16;

imuTabView = IMUTabView( "Parent", imuTab, ...
    "FontSize", fontSize );
sessionTabView = SessionTabView( "Parent", sessionTab, ...
    "FontSize", fontSize );

% Create the controllers
imuTabController = IMUTabController( model, imuTabView );
SessionTabController( imuTabController.Model, sessionTabView);

% Return the figure handle if requested
if nargout > 0
    nargoutchk( 1, 1 )
    varargout{1} = f;
end % if

function onTabChanged( ~, ~, ~ )
    
end % onTabChanged

end % launchMVCApp