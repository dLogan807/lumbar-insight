classdef FileWriter < handle
    %Class for managing data written to .csv files and accompanying videos

    properties (SetAccess = private)
        ParentExportDir string {mustBeTextScalar} = ""
        FullExportDir string {mustBeTextScalar} = ""
        CSVInUse string {mustBeTextScalar} = ""
        WebcamVideo = []
        IPCamVideo = []
        CSVInitialised logical {mustBeNonempty} = false;
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

        function initialiseNewCSV(obj)
            %Create a new csv file with headers

            if (obj.CSVInitialised)
                error("initialiseNewFile:FileAlreadyInitialised", "Close the file before creating a new one.")
            end

            try
                obj.CSVInUse = generateFileName(obj, "", ".csv");
            catch
                warning("Could not generate csv file name. CSV recording will not proceed.")
                return
            end

            csvHeaders = ["Date and Time", "Angle", "Threshold Angle", "Exceeded Threshold?"];

            createDirIfNotExist(obj, obj.FullExportDir);

            fullPath = obj.FullExportDir + "\" + obj.CSVInUse;

            writematrix(csvHeaders, fullPath);

            obj.CSVInitialised = true;
            obj.ProhibitWriteFlag = false;
        end

        function initialiseNewVideoFile(obj, cameraName, fps)
            %Add new camera to the dictionary and open its VideoWriter

            arguments
                obj 
                cameraName string {mustBeTextScalar, mustBeNonempty} 
                fps double {mustBePositive, mustBeNonempty}
            end

            if (strcmp(cameraName, "Webcam") && isempty(obj.WebcamVideo))
                obj.closeVideoFile(obj.WebcamVideo);
            elseif (strcmp(cameraName, "IPCam") && isempty(obj.IPCamVideo))
                obj.closeVideoFile(obj.IPCamVideo);
            end

            try 
                videoFileName = generateFileName(obj, cameraName, ".mp4");
            catch
                warning("Could not generate video file name. Video recording will not proceed.")
                return
            end
        
            fullPath = obj.FullExportDir + "\" + videoFileName;
            videoWriter = VideoWriter(fullPath, "MPEG-4");
            videoWriter.FrameRate = fps;
            open(videoWriter);
            
            if (strcmp(cameraName, "Webcam"))
                obj.WebcamVideo = videoWriter;
            else
                obj.IPCamVideo = videoWriter;
            end
        end
        
        function writeAngleData(obj, dataArray)
            %Write body data to the csv file

            arguments
                obj
                dataArray (1, 4) {mustBeNonempty}
            end

            if (obj.ProhibitWriteFlag)
                error("writeAngleData:FileNotInitialised", "Initialise writing data.")
            elseif (~obj.CSVInitialised)
                return
            end

            writeToCSV(obj, dataArray);
        end

        function writeToVideo(obj, cameraName, imageFrame)
            arguments
                obj 
                cameraName string {mustBeNonempty, mustBeTextScalar} 
                imageFrame 
            end

            if (strcmp(cameraName, "Webcam") && isempty(obj.WebcamVideo))
                warning("Cannot write video: Camera " +  cameraName + " not initialised.")
                return
            elseif (strcmp(cameraName, "IPCam") && isempty(obj.IPCamVideo))
                warning("Cannot write video: Camera " +  cameraName + " not initialised.")
                return
            end
            
            if (strcmp(cameraName, "Webcam"))
                writeVideo(obj.WebcamVideo, imageFrame);
            else
                writeVideo(obj.IPCamVideo, imageFrame);
            end
        end

        function closeCSVFile(obj, dataArray)
            %Write closing data to file and delete file name references

            arguments
                obj
                dataArray (1, 4) double {mustBeNonempty}
            end

            if (~obj.CSVInitialised)
                error("closeCSV:FileNotInitialised", "Initialise the file before closing.")
            end

            headers = ["Smallest Angle", "Largest Angle", "Time Above Threshold Angle", "Recording duration"];
            
            %Prevent further writes while adding closing data
            obj.ProhibitWriteFlag = true;

            writeToCSV(obj, headers);
            writeToCSV(obj, round(dataArray, 2));
                
            obj.CSVInUse = "";
            obj.CSVInitialised = false;
        end

        function closeVideoFiles(obj)
            %Close all open video files in the dictionary

            closeVideoFile(obj, "Webcam");
            closeVideoFile(obj, "IPCam");

        end

        function closeVideoFile(obj, cameraName)
            %Close a specific camera's video

            if (strcmp(cameraName, "Webcam") && ~isempty(obj.WebcamVideo))
                close(obj.WebcamVideo);
                obj.WebcamVideo = [];
            elseif (strcmp(cameraName, "IPCam") && ~isempty(obj.IPCamVideo))
                close(obj.IPCamVideo);
                obj.IPCamVideo = [];
            end
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

        function fileName = generateFileName(obj, prefix, extension)
            %Generated a formatted file name

            arguments
                obj 
                prefix string {mustBeTextScalar}
                extension string {mustBeNonempty, mustBeTextScalar} 
            end

            if (~isValidExtension(obj, extension))
                error("generateFileName:InvalidExtension", "An invalid file extension was provided.")
            end

            currentTime = datetime('now');

            fileName = currentTime.Day + "-" + currentTime.Month + "-" + currentTime.Year + "--" + formatTime(obj, currentTime.Hour) + "-" + formatTime(obj, currentTime.Minute) + "-" + formatTime(obj, currentTime.Second) + extension;

            if (~isempty(prefix) && strlength(prefix) > 0)
                fileName = prefix + "-" + fileName;
            end
        end

        function isValid = isValidExtension(~, extension)
            %Check if the provided extension is valid

            arguments
                ~ 
                extension string {mustBeTextScalar}
            end

            validExtensions = [".csv",".mp4",".avi"];

            if (any(matches(extension, validExtensions)))
                isValid = true;
            else
                isValid = false;
            end
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

        function writeToCSV(obj, dataArray)
            %Write data of any format to the file

            arguments
                obj
                dataArray (1, :) {mustBeNonempty}
            end

            if (strcmp(obj.CSVInUse, ""))
                warning("FileWriter.writeToFile: file not initialised. Data not recorded.")
                return
            end

            fullPath = obj.FullExportDir + "\" + obj.CSVInUse;

            writematrix(dataArray, fullPath, ...
                "WriteMode", "append");
        end

    end

end
