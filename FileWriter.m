classdef FileWriter < handle
    %Class for managing data written to .csv files and accompanying videos
    
    properties (SetAccess = private, GetAccess = public)
        ParentExportDir
        CurrentExportDir
    end
    
    methods
        function obj = FileWriter(exportParentDir)
            %Constructor. Creates parent export folder.

            arguments
                exportParentDir string {mustBeTextScalar, mustBeNonempty}
            end

            makeDirIfNotExist(obj, exportParentDir);

            obj.ParentExportDir = exportParentDir;
            currentDate = datetime('now');
            obj.CurrentExportDir = exportParentDir + "/" + string(currentDate.Day + "-" + currentDate.Month + "-" + currentDate.Year);
        end
    end

    methods (Access = private)
        function makeDirIfNotExist(~, directory)
            arguments
                ~
                directory string {mustBeTextScalar, mustBeNonempty}
            end

            %Create directory if not existing
            if ~exist(directory, 'dir')
               mkdir(directory)
            end
        end
    end
end

