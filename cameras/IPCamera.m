classdef IPCamera < CameraInterface
    
    properties (SetAccess = private)
        Camera
        Frame
        Feedback string = ""
        IsConnected = false
    end
    
    methods
        function connected = connect(obj, url, username, password)
            try 
                obj.Camera = ipcam(url, username, password);
                obj.Frame = snapshot(obj.Camera);
                obj.IsConnected = true;
                connected = true;
            catch exception
                disp("Could not connect to IP Camera: " + exception.message);

                if (strcmp(exception.identifier, 'MATLAB:validators:mustBeNonzeroLengthText'))
                    obj.Feedback = "Please fill out all fields.";
                elseif (strcmp(exception.identifier, "MATLAB:ipcamera:ipcam:needHTTPorRTSPStreamURL"))
                    obj.Feedback = "URL input needs to be a MJPEG HTTP/RTSP or H.264 RTSP URL.";
                elseif (strcmp(exception.identifier, "MATLAB:ipcamera:ipcam:incorrectCredentials"))
                    obj.Feedback = "Incorrect Username or Password.";
                elseif (strcmp(exception.identifier, "MATLAB:ipcamera:ipcam:cannotConnect"))
                    obj.Feedback = "Incorrect URL or authentication needed.";
                else
                    obj.Feedback = "An error occured.";
                end

                connected = false;
            end
        end

        function disconnect(obj)
            if (~isempty(obj.Camera))
                closePreview(obj.Camera)
                clear obj.Camera;
                clear obj.Frame;
                obj.IsConnected = false;
            end
        end

        function preview(obj, camImage)

            if (isempty(obj.Camera))
                return
            end

            preview(obj.Camera, camImage);
        end

        function stopPreview(obj)
            if (isempty(obj.Camera))
                return
            end

            closePreview(obj.Camera);
        end
    end
end

