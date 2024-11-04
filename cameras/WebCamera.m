classdef WebCamera < CameraInterface
    
    properties (SetAccess = private)
        Camera
        Frame
        Name string = []
        IsConnected = false
    end
    
    methods

        function connected = connect(obj, cameraName)
            try
                obj.Camera = webcam(cameraName);
                obj.Frame = snapshot(obj.Camera);
                obj.Name = cameraName;
                obj.IsConnected = true;
                connected = true;
            catch
                obj.IsConnected = false;
                connected = false;
            end
        end

        function disconnect(obj)
            if (~isempty(obj.Camera))
                closePreview(obj.Camera)
                clear obj.Camera;
                clear obj.Frame;
            end
            obj.Name = [];
            obj.IsConnected = false;
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

