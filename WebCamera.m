classdef WebCamera < handle
    
    properties (SetAccess = private)
        Camera webcam
        Frame
        Name string = []
        IsConnected logical {mustBeNonempty} = false
        IsPreviewing logical {mustBeNonempty} = false
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
                disp("Could not connect to " + cameraName);
                connected = false;
            end
        end

        function disconnect(obj)
            if (~isempty(obj.Camera))
                closePreview(obj.Camera)
                clear obj.Camera;
                clear obj.Frame;
                obj.Name = [];
                obj.IsConnected = false;
            end
            
            obj.IsPreviewing = false;
        end

        function preview(obj, camImage)

            if (isempty(obj.Camera) || obj.IsPreviewing)
                return
            end

            preview(obj.Camera, camImage);
            obj.IsPreviewing = true;
        end

        function stopPreview(obj)
            if (isempty(obj.Camera) || ~obj.IsPreviewing)
                return
            end

            closePreview(obj.Camera);
            obj.IsPreviewing = false;
        end
    end
end

