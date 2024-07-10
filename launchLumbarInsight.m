function varargout = launchLumbarInsight( f )
%LAUNCHLUMBARINSIGHT Launch the application.

arguments
    f(1, 1) matlab.ui.Figure = uifigure()
end % arguments

% Rename figure.
f.Name = "Lumbar Insight";

% Create the layout.
g = uigridlayout( ...
    "Parent", f, ...
    "RowHeight", {"1x"}, ...
    "ColumnWidth", "1x" );

% Create tab group
tabgroup = uitabgroup(g, "SelectionChangedFcn", @onTabChanged);
imuTab = uitab(tabgroup,"Title","IMU Configuration");
cameraTab = uitab(tabgroup,"Title","Camera Configuration");
sessionTab = uitab(tabgroup,"Title","Session");
managementTab = uitab(tabgroup,"Title","Session Management");

% Create the model.
model = Model;

% Create the views
imuTabView = IMUTabView( "Parent", imuTab );
sessionTabView = SessionTabView( "Parent", sessionTab );

% Create the controllers
imuTabController = IMUTabController( model, imuTabView );
SessionTabController( imuTabController.Model, sessionTabView);

% Return the figure handle if requested.
if nargout > 0
    nargoutchk( 1, 1 )
    varargout{1} = f;
end % if

function onTabChanged( ~, ~, ~ )
    
end % onTabChanged

end % launchMVCApp