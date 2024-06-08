classdef Model < handle
    %MODEL Application data model.
    
    properties ( SetAccess = private )
        % Application data.

        Shimmers (1,2) ShimmerHandleClass

        Cameras (1,:) Camera
    end % properties ( SetAccess = private )
    
    events ( NotifyAccess = private )
        % Event broadcast when the data is changed.
        Shimmer1Changed
        Shimmer2Changed

        SessionStarted
    end % events ( NotifyAccess = private )
    
    methods

        function connectShimmer( shimmerNum, obj ) 
        
            obj.Shimmers(shimmerNum).connect;

            notify( obj, "ConnectedShimmer" + shimmerNum )

        end % connectShimmer

        function disconnectShimmer( shimmerNum, obj ) 
        
            obj.Shimmers(shimmerNum).disconnect;

            notify( obj, "DisconnectedShimmer" + shimmerNum )

        end % disconnectShimmer

        function configureShimmers( obj) 
        end

        function startSession( obj ) 
        
            obj.Shimmers(1).start;
            obj.Shimmers(2).start;

            notify( obj, "SessionStarted" )

        end % startSession

        function endSession( obj ) 
        
            obj.Shimmers(1).stop;
            obj.Shimmers(2).stop;

            notify( obj, "SessionStarted" )

        end % startSession
        
    end % methods
    
end % classdef