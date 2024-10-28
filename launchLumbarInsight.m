%Script for launching the application

%Whether to allow multiple open windows of the app. May cause problems if
%enabled.
allowMultipleAppInstances = false;

if (allowMultipleAppInstances)
    LumbarInsightMultiple;
else
    LumbarInsight.instance;
end
