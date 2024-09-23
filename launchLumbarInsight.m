%Script for launching the application

%Whether to allow multiple open windows of the app
allowMultipleAppInstances = true;

if (allowMultipleAppInstances)
    NonSingletonLumbarInsight
else
    LumbarInsight.instance;
end
