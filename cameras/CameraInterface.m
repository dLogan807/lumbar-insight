classdef CameraInterface < handle
    
    properties (Abstract, SetAccess = private)
        Camera webcam
        Frame
        Name string
        IsConnected logical {mustBeNonempty}
    end
    
    methods (Abstract)
        connected = connect(obj, cameraName)

        disconnect(obj)

        preview(obj, camImage)

        stopPreview(obj)
    end
end

