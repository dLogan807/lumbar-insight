classdef IPCamera < CameraInterface
    
    properties (SetAccess = private)
        Camera
        Frame
        ErrorMessage
        IsConnected = false
    end
    
    methods
        function connected = connect(obj, username, password, url)
            try
                obj.Camera = ipcam(url, username, password);
                obj.Frame = snapshot(obj.Camera);
                obj.IsConnected = true;
                connected = true;
            catch exception
                disp("Could not connect to IP Camera: " + exception.message);

                disp(exception.identifier);
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

