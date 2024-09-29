classdef FileWriter < handle
    %Class for managing data written to .csv files and accompanying videos

    properties (SetAccess = private)
        ParentExportDir string {mustBeTextScalar} = ""
        FullExportDir string {mustBeTextScalar} = ""
        FileInUse string {mustBeTextScalar} = ""
        FileInitialised logical {mustBeNonempty} = false;
    end

    properties (Access = private)
        ProhibitWriteFlag logical {mustBeNonempty} = true;
    end

    methods

        function obj = FileWriter(exportParentDir)
            %Constructor. Creates parent export folder.

            arguments
                exportParentDir string {mustBeTextScalar, mustBeNonempty}
            end

            createDirIfNotExist(obj, exportParentDir);
            obj.ParentExportDir = exportParentDir;

            currentTime = datetime('now');
            obj.FullExportDir = exportParentDir + "\" + string(currentTime.Day + "-" + currentTime.Month + "-" + currentTime.Year);
        end

        function initialiseNewFile(obj)
            %Create a new file with headers

            if (obj.FileInitialised)
                error("initialiseNewFile:FileAlreadyInitialised", "Close the file before creating a new one.")
            end

            obj.FileInitialised = true;
            csvHeaders = ["Date and Time", "Angle", "Threshold Angle", "Exceeded Threshold?"];

            obj.FileInUse = generateFileName(obj);

            createDirIfNotExist(obj, obj.FullExportDir);

            fullPath = obj.FullExportDir + "\" + obj.FileInUse;

            writematrix(csvHeaders, fullPath);

            obj.ProhibitWriteFlag = false;
        end
        
        function writeAngleData(obj, dataArray)
            %Write body data to the csv file

            arguments
                obj
                dataArray (1, 4) {mustBeNonempty}
            end

            if (obj.ProhibitWriteFlag)
                error("writeAngleData:FileNotInitialised", "Initialise writing data.")
            elseif (~obj.FileInitialised)
                return
            end

            writeToFile(obj, dataArray);
        end

        function closeFile(obj, dataArray)
            %Write closing data to file and delete file name reference

            arguments
                obj
                dataArray (1, 4) double {mustBeNonempty}
            end

            if (~obj.FileInitialised)
                error("closeFile:FileNotInitialised", "Initialise the file before closing.")
            end

            headers = ["Smallest Angle", "Largest Angle", "Time Above Threshold Angle", "Recording duration"];
            
            %Prevent further writes while adding closing data
            obj.ProhibitWriteFlag = true;

            writeToFile(obj, headers);
            writeToFile(obj, round(dataArray, 2));
                
            obj.FileInUse = "";
            obj.FileInitialised = false;
        end

    end

    methods (Access = private)

        function createDirIfNotExist(~, directory)
            %Create directory if not existing

            arguments
                ~
                directory string {mustBeTextScalar, mustBeNonempty}
            end

            if ~exist(directory, 'dir')
                mkdir(directory)
            end

        end

        function fileName = generateFileName(obj)
            %Generated a formatted file name for this recording
            currentTime = datetime('now');

            fileName = currentTime.Day + "-" + currentTime.Month + "-" + currentTime.Year + "--" + formatTime(obj, currentTime.Hour) + "-" + formatTime(obj, currentTime.Minute) + "-" + formatTime(obj, currentTime.Second) + ".csv";
        end

        function formattedText = formatTime(~, time)
            %Round and add a leading zero if only one character is present

            arguments
                ~
                time double
            end

            if (isempty(time))
                formattedText = "00";
                return
            end

            timeString = string(round(time, 0));

            if (strlength(timeString) == 1)
                formattedText = "0" + timeString;
            else
                formattedText = timeString;
            end

        end

        function writeToFile(obj, dataArray)
            %Write data of any format to the file

            arguments
                obj
                dataArray (1, :) {mustBeNonempty}
            end

            if (strcmp(obj.FileInUse, ""))
                warning("FileWriter.writeToFile: file not initialised. Data not recorded.")
                return
            end

            fullPath = obj.FullExportDir + "\" + obj.FileInUse;

            writematrix(dataArray, fullPath, ...
                "WriteMode", "append");
        end

    end

end
