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
shimmerTab = uitab(tabgroup,"Title","Shimmer Configuration");
cameraTab = uitab(tabgroup,"Title","Camera Configuration");
sessionTab = uitab(tabgroup,"Title","Session");
visualisationTab = uitab(tabgroup,"Title","3D Visualisation");
managementTab = uitab(tabgroup,"Title","Session Management");

% Create the model.
model = Model;

% Create the Shimmer view.
shimmerTabView = ShimmerTabView( model, "Parent", shimmerTab );

% Create the Shimmer controller.
ShimmerTabController( model, shimmerTabView );

% Return the figure handle if requested.
if nargout > 0
    nargoutchk( 1, 1 )
    varargout{1} = f;
end % if

function onTabChanged( ~, ~, ~ )

    disp("Tab changed!");
    
end % onTabChanged

end % launchMVCApp