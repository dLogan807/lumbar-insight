classdef CameraInterface < handle
    
    properties (Abstract, SetAccess = private)
        Camera
        Frame
        IsConnected logical {mustBeNonempty}
    end
    
    methods (Abstract)
        connected = connect(obj)

        disconnect(obj)

        preview(obj, camImage)

        stopPreview(obj)
    end
end

