function orientation3D(shimmer1, shimmer2, captureDuration)
%ORIENTATION3DEXAMPLE - Demonstrate 3D orientation visualation and write to file
%
%  ORIENTATION3DEXAMPLE(COMPORT, CAPTUREDURATION, FILENAME) streams 3
%  accelerometer signals, 3 gyroscope signals and 3 magnetometer signals,
%  from the Shimmer paired with COMPORT, estimates the 3D orientation in
%  quaternion format and displays a 3D graphic to visualise the
%  orientation. The "Set" and "Reset" buttons on the graph display can be
%  used to change the viewpoint of the graph so that the visualisation of
%  the device matches the viewpoint of the user, relative to the physical
%  device. The function
%  will stream data for a fixed duration of time defined by the constant
%  CAPTUREDURATION. The function also writes the data in a tab delimited
%  format to the file defined in FILENAME.
%  NOTE: This example uses the method 'getdata' which is a more advanced
%  alternative to the 'getuncalibrateddata' method in the beta release.
%  The user is advised to use the updated method 'getdata'.
%
%  SYNOPSIS: orientation3Dexample(shimmer1, shimmer2, captureDuration)
%
%  INPUT: comPort - String value defining the COM port number for Shimmer
%  INPUT: captureDuration - Numerical value defining the period of time
%                           (in seconds) for which the function will stream
%                           data from  the Shimmers.
%  INPUT : fileName - String value defining the name of the file that data
%                     is written to in a comma delimited format.
%  OUTPUT: none

addpath('./quaternion/')                                                   % directory containing quaternion functions

% Note: these constants are only relevant to this examplescript and are not used
% by the ShimmerHandle Class
DELAY_PERIOD = 0.05;                                                       % A delay period of time in seconds between data read operations

if (shimmer1.connect && shimmer2.connect)                                  % TRUE if the shimmers connect
   
    configureShimmer(shimmer1);
    configureShimmer(shimmer2);
    
    if (shimmer1.start && shimmer2.start)                % TRUE if the shimmers start streaming

        fig = uifigure;
        tlabel1 = uilabel(fig);
        tlabel1.Position = [50 50 150 22];
        
        % initial viewpoint for 3D visualisation
        cameraUpVector = [0,1,0,0];
        cameraPosition = [0,0,0,1];
        
        layout = tiledlayout(1,2,'TileSpacing','Compact');
        layout.Padding = "tight";
        layout.TileSpacing = 'none';

        shimmer1AllData = [];
        shimmer2AllData = [];
        
        uicontrol('Style', 'pushbutton', 'String', 'Set',...
            'Position', [20 20 50 20],...
            'Callback', {@setaxes});                                       % Pushbutton to set the viewpoint
        
        uicontrol('Style', 'pushbutton', 'String', 'Reset',...
            'Position', [80 20 50 20],...
            'Callback', {@resetaxes});                                     % Pushbutton to reset the viewpoint
        
        elapsedTime = 0;                                                   % Reset to 0
        
        tic;                                                               % Start timer
        
        while (elapsedTime < captureDuration)
            
            pause(DELAY_PERIOD);                                           % Pause for this period of time on each iteration to allow data to arrive in the buffer
            
            [shimmer1NewData,shimmer1SignalNameArray,shimmer1SignalFormatArray,shimmer1SignalUnitArray] = shimmer1.getdata('c');   % Read the latest data from shimmer data buffer, signalFormatArray defines the format of the data and signalUnitArray the unit
            [shimmer2NewData,shimmer2SignalNameArray,shimmer2SignalFormatArray,shimmer2SignalUnitArray] = shimmer2.getdata('c');

            if (~isempty(shimmer1NewData) && ~isempty(shimmer2NewData))                                                                          % TRUE if new data has arrived
                
                shimmer1AllData = [shimmer1AllData; shimmer1NewData];
                shimmer2AllData = [shimmer2AllData; shimmer2NewData];
                
                shimmer1QuaternionChannels(1) = find(ismember(shimmer1SignalNameArray, 'Quaternion 0'));                  % Find Quaternion signal indices.
                shimmer1QuaternionChannels(2) = find(ismember(shimmer1SignalNameArray, 'Quaternion 1'));
                shimmer1QuaternionChannels(3) = find(ismember(shimmer1SignalNameArray, 'Quaternion 2'));
                shimmer1QuaternionChannels(4) = find(ismember(shimmer1SignalNameArray, 'Quaternion 3'));

                shimmer2QuaternionChannels(1) = find(ismember(shimmer2SignalNameArray, 'Quaternion 0'));                  % Find Quaternion signal indices.
                shimmer2QuaternionChannels(2) = find(ismember(shimmer2SignalNameArray, 'Quaternion 1'));
                shimmer2QuaternionChannels(3) = find(ismember(shimmer2SignalNameArray, 'Quaternion 2'));
                shimmer2QuaternionChannels(4) = find(ismember(shimmer2SignalNameArray, 'Quaternion 3'));

                shimmer1Quaternion = shimmer1NewData(end, shimmer1QuaternionChannels);                                            % Only use the most recent quaternion sample for the graphic
                shimmer2Quaternion = shimmer2NewData(end, shimmer2QuaternionChannels);

                rotateVertices(shimmer1, shimmer1Quaternion);
                rotateVertices(shimmer2, shimmer2Quaternion);

                plotShimmer(shimmer1, 1);
                plotShimmer(shimmer2, 2);

                calculateAngle(shimmer1Quaternion, shimmer2Quaternion);
            end
            
            elapsedTime = elapsedTime + toc;                                                              % Stop timer and add to elapsed time
            tic;                                                                                          % Start timer
            
        end
        
        elapsedTime = elapsedTime + toc;                                                                  % Stop timer
        fprintf(shimmer1.name + ' percentage of received packets: %d \n',shimmer1.getpercentageofpacketsreceived(shimmer1AllData(:,1))); % Detect lost packets
        fprintf(shimmer2.name + ' percentage of received packets: %d \n',shimmer1.getpercentageofpacketsreceived(shimmer1AllData(:,1)));
        shimmer1.stop;                                                                                     % Stop data streaming
        shimmer2.stop;
    end
    shimmer1.disconnect;                                                                                   % Disconnect from shimmer
    shimmer2.disconnect;
    
end

    function configureShimmer(shimmer)
        % Define settings for shimmer
        
        SensorMacros = ShimmerEnabledSensorsMacrosClass;                           % assign user friendly macros for setenabledsensors

        shimmer.setsamplingrate(51.2);                                         % Set the shimmer sampling rate to 51.2Hz
    	shimmer.setinternalboard('9DOF');                                      % Set the shimmer internal daughter board to '9DOF'
        shimmer.disableallsensors;                                             % disable all sensors
        shimmer.setenabledsensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,...   % Enable the gyroscope, magnetometer and accelerometer.
        SensorMacros.ACCEL,1);                                                  
        shimmer.setaccelrange(0);                                              % Set the accelerometer range to 0 (+/- 1.5g for Shimmer2/2r, +/- 2.0g for Shimmer3)
        shimmer.setorientation3D(1);                                           % Enable orientation3D
        shimmer.setgyroinusecalibration(1);                                    % Enable gyro in-use calibration
    end

    function rotateVertices(shimmer, quaternion)
        shimmer.shimmer3dRotated.p1 = quatrotate(quaternion, [0 shimmer.shimmer3d.p1]);                           % Rotate the vertices
        shimmer.shimmer3dRotated.p2 = quatrotate(quaternion, [0 shimmer.shimmer3d.p2]);
        shimmer.shimmer3dRotated.p3 = quatrotate(quaternion, [0 shimmer.shimmer3d.p3]);
        shimmer.shimmer3dRotated.p4 = quatrotate(quaternion, [0 shimmer.shimmer3d.p4]);
        shimmer.shimmer3dRotated.p5 = quatrotate(quaternion, [0 shimmer.shimmer3d.p5]);
        shimmer.shimmer3dRotated.p6 = quatrotate(quaternion, [0 shimmer.shimmer3d.p6]);
        shimmer.shimmer3dRotated.p7 = quatrotate(quaternion, [0 shimmer.shimmer3d.p7]);
        shimmer.shimmer3dRotated.p8 = quatrotate(quaternion, [0 shimmer.shimmer3d.p8]);
        shimmer.shimmer3dRotated.p9 = quatrotate(quaternion, [0 shimmer.shimmer3d.p9]);
        shimmer.shimmer3dRotated.p10 = quatrotate(quaternion, [0 shimmer.shimmer3d.p10]);
        shimmer.shimmer3dRotated.p11 = quatrotate(quaternion, [0 shimmer.shimmer3d.p11]);
        shimmer.shimmer3dRotated.p12 = quatrotate(quaternion, [0 shimmer.shimmer3d.p12]);
        shimmer.shimmer3dRotated.p13 = quatrotate(quaternion, [0 shimmer.shimmer3d.p13]);
        shimmer.shimmer3dRotated.p14 = quatrotate(quaternion, [0 shimmer.shimmer3d.p14]);
        shimmer.shimmer3dRotated.p15 = quatrotate(quaternion, [0 shimmer.shimmer3d.p15]);
        shimmer.shimmer3dRotated.p16 = quatrotate(quaternion, [0 shimmer.shimmer3d.p16]);
    end
    
    function convexArray = generateConvexHullArray(shimmer)
        x = [shimmer.shimmer3dRotated.p1(2),shimmer.shimmer3dRotated.p2(2),shimmer.shimmer3dRotated.p3(2),shimmer.shimmer3dRotated.p4(2),...      % Calculate the convex hull for the graphic
             shimmer.shimmer3dRotated.p5(2),shimmer.shimmer3dRotated.p6(2),shimmer.shimmer3dRotated.p7(2),shimmer.shimmer3dRotated.p8(2),...      
             shimmer.shimmer3dRotated.p9(2),shimmer.shimmer3dRotated.p10(2),shimmer.shimmer3dRotated.p11(2),shimmer.shimmer3dRotated.p12(2)]';
        y = [shimmer.shimmer3dRotated.p1(3),shimmer.shimmer3dRotated.p2(3),shimmer.shimmer3dRotated.p3(3),shimmer.shimmer3dRotated.p4(3),...
             shimmer.shimmer3dRotated.p5(3),shimmer.shimmer3dRotated.p6(3),shimmer.shimmer3dRotated.p7(3),shimmer.shimmer3dRotated.p8(3),...      
             shimmer.shimmer3dRotated.p9(3),shimmer.shimmer3dRotated.p10(3),shimmer.shimmer3dRotated.p11(3),shimmer.shimmer3dRotated.p12(3)]';
        z = [shimmer.shimmer3dRotated.p1(4),shimmer.shimmer3dRotated.p2(4),shimmer.shimmer3dRotated.p3(4),shimmer.shimmer3dRotated.p4(4),...
             shimmer.shimmer3dRotated.p5(4),shimmer.shimmer3dRotated.p6(4),shimmer.shimmer3dRotated.p7(4),shimmer.shimmer3dRotated.p8(4),...      
             shimmer.shimmer3dRotated.p9(4),shimmer.shimmer3dRotated.p10(4),shimmer.shimmer3dRotated.p11(4),shimmer.shimmer3dRotated.p12(4)]';

        convexArray = [x,y,z];
    end

    function plotOutlines(shimmer) 
        % Plot object outlines
        plot3([shimmer.shimmer3dRotated.p1(2), shimmer.shimmer3dRotated.p2(2)],[shimmer.shimmer3dRotated.p1(3), shimmer.shimmer3dRotated.p2(3)],[shimmer.shimmer3dRotated.p1(4), shimmer.shimmer3dRotated.p2(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p2(2), shimmer.shimmer3dRotated.p3(2)],[shimmer.shimmer3dRotated.p2(3), shimmer.shimmer3dRotated.p3(3)],[shimmer.shimmer3dRotated.p2(4), shimmer.shimmer3dRotated.p3(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p3(2), shimmer.shimmer3dRotated.p4(2)],[shimmer.shimmer3dRotated.p3(3), shimmer.shimmer3dRotated.p4(3)],[shimmer.shimmer3dRotated.p3(4), shimmer.shimmer3dRotated.p4(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p4(2), shimmer.shimmer3dRotated.p1(2)],[shimmer.shimmer3dRotated.p4(3), shimmer.shimmer3dRotated.p1(3)],[shimmer.shimmer3dRotated.p4(4), shimmer.shimmer3dRotated.p1(4)],'-k','LineWidth',2)
        
        plot3([shimmer.shimmer3dRotated.p5(2), shimmer.shimmer3dRotated.p6(2)],[shimmer.shimmer3dRotated.p5(3), shimmer.shimmer3dRotated.p6(3)],[shimmer.shimmer3dRotated.p5(4), shimmer.shimmer3dRotated.p6(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p6(2), shimmer.shimmer3dRotated.p7(2)],[shimmer.shimmer3dRotated.p6(3), shimmer.shimmer3dRotated.p7(3)],[shimmer.shimmer3dRotated.p6(4), shimmer.shimmer3dRotated.p7(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p7(2), shimmer.shimmer3dRotated.p8(2)],[shimmer.shimmer3dRotated.p7(3), shimmer.shimmer3dRotated.p8(3)],[shimmer.shimmer3dRotated.p7(4), shimmer.shimmer3dRotated.p8(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p8(2), shimmer.shimmer3dRotated.p5(2)],[shimmer.shimmer3dRotated.p8(3), shimmer.shimmer3dRotated.p5(3)],[shimmer.shimmer3dRotated.p8(4), shimmer.shimmer3dRotated.p5(4)],'-k','LineWidth',2)
        
        plot3([shimmer.shimmer3dRotated.p9(2), shimmer.shimmer3dRotated.p10(2)],[shimmer.shimmer3dRotated.p9(3), shimmer.shimmer3dRotated.p10(3)],[shimmer.shimmer3dRotated.p9(4), shimmer.shimmer3dRotated.p10(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p10(2), shimmer.shimmer3dRotated.p11(2)],[shimmer.shimmer3dRotated.p10(3), shimmer.shimmer3dRotated.p11(3)],[shimmer.shimmer3dRotated.p10(4), shimmer.shimmer3dRotated.p11(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p11(2), shimmer.shimmer3dRotated.p12(2)],[shimmer.shimmer3dRotated.p11(3), shimmer.shimmer3dRotated.p12(3)],[shimmer.shimmer3dRotated.p11(4), shimmer.shimmer3dRotated.p12(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p12(2), shimmer.shimmer3dRotated.p9(2)],[shimmer.shimmer3dRotated.p12(3), shimmer.shimmer3dRotated.p9(3)],[shimmer.shimmer3dRotated.p12(4), shimmer.shimmer3dRotated.p9(4)],'-k','LineWidth',2)
        
        plot3([shimmer.shimmer3dRotated.p1(2), shimmer.shimmer3dRotated.p5(2)],[shimmer.shimmer3dRotated.p1(3), shimmer.shimmer3dRotated.p5(3)],[shimmer.shimmer3dRotated.p1(4), shimmer.shimmer3dRotated.p5(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p2(2), shimmer.shimmer3dRotated.p6(2)],[shimmer.shimmer3dRotated.p2(3), shimmer.shimmer3dRotated.p6(3)],[shimmer.shimmer3dRotated.p2(4), shimmer.shimmer3dRotated.p6(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p3(2), shimmer.shimmer3dRotated.p7(2)],[shimmer.shimmer3dRotated.p3(3), shimmer.shimmer3dRotated.p7(3)],[shimmer.shimmer3dRotated.p3(4), shimmer.shimmer3dRotated.p7(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p4(2), shimmer.shimmer3dRotated.p8(2)],[shimmer.shimmer3dRotated.p4(3), shimmer.shimmer3dRotated.p8(3)],[shimmer.shimmer3dRotated.p4(4), shimmer.shimmer3dRotated.p8(4)],'-k','LineWidth',2)
        
        plot3([shimmer.shimmer3dRotated.p1(2), shimmer.shimmer3dRotated.p9(2)],[shimmer.shimmer3dRotated.p1(3), shimmer.shimmer3dRotated.p9(3)],[shimmer.shimmer3dRotated.p1(4), shimmer.shimmer3dRotated.p9(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p2(2), shimmer.shimmer3dRotated.p10(2)],[shimmer.shimmer3dRotated.p2(3), shimmer.shimmer3dRotated.p10(3)],[shimmer.shimmer3dRotated.p2(4), shimmer.shimmer3dRotated.p10(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p3(2), shimmer.shimmer3dRotated.p11(2)],[shimmer.shimmer3dRotated.p3(3), shimmer.shimmer3dRotated.p11(3)],[shimmer.shimmer3dRotated.p3(4), shimmer.shimmer3dRotated.p11(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p4(2), shimmer.shimmer3dRotated.p12(2)],[shimmer.shimmer3dRotated.p4(3), shimmer.shimmer3dRotated.p12(3)],[shimmer.shimmer3dRotated.p4(4), shimmer.shimmer3dRotated.p12(4)],'-k','LineWidth',2)
        
        % Plot outline of dock connector
        plot3([shimmer.shimmer3dRotated.p13(2), shimmer.shimmer3dRotated.p14(2)],[shimmer.shimmer3dRotated.p13(3), shimmer.shimmer3dRotated.p14(3)],[shimmer.shimmer3dRotated.p13(4), shimmer.shimmer3dRotated.p14(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p14(2), shimmer.shimmer3dRotated.p15(2)],[shimmer.shimmer3dRotated.p14(3), shimmer.shimmer3dRotated.p15(3)],[shimmer.shimmer3dRotated.p14(4), shimmer.shimmer3dRotated.p15(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p15(2), shimmer.shimmer3dRotated.p16(2)],[shimmer.shimmer3dRotated.p15(3), shimmer.shimmer3dRotated.p16(3)],[shimmer.shimmer3dRotated.p15(4), shimmer.shimmer3dRotated.p16(4)],'-k','LineWidth',2)
        plot3([shimmer.shimmer3dRotated.p16(2), shimmer.shimmer3dRotated.p13(2)],[shimmer.shimmer3dRotated.p16(3), shimmer.shimmer3dRotated.p13(3)],[shimmer.shimmer3dRotated.p16(4), shimmer.shimmer3dRotated.p13(4)],'-k','LineWidth',2)
    end

    function plotShimmer(shimmer, tileNum)
        X = generateConvexHullArray(shimmer);
        K = convhulln(X);

        nexttile(tileNum);

        hold off;
        % Plot object surface
        trisurf(K,X(:,1),X(:,2),X(:,3),'EdgeColor','None','FaceColor','w');
        hold on;

        plotOutlines(shimmer);

        xlim([-2,2])
        ylim([-2,2])
        zlim([-2,2])

        view(cameraPosition(2:4))
        set(gca,'CameraUpVector',cameraUpVector(2:4));

        ax = gca;

        ax.XAxis.Visible = 'off';
        ax.YAxis.Visible = 'off';

        grid off;
    end

    function setaxes(hObj,event) 
        % Called when user presses "Set" button  

        % Calculate camera position and angle for front view
        cameraPosition = quatrotate(shimmer1Quaternion,[0,0,0,1]);
        cameraUpVector = quatrotate(shimmer1Quaternion,[0,-1,0,0]); % orientation for Shimmer3
    end

    function resetaxes(hObj,event) 
        % Called when user presses "reset" button  

        % Reset camera position and angle to original view
        cameraPosition = [0,0,0,1];
        cameraUpVector = [0,1,0,0];

    end

    % https://au.mathworks.com/matlabcentral/answers/476474-how-to-find-the-angle-between-two-quaternions
    function angle = calculateAngle(quaternion1, quaternion2)
        z = quatmultiply(quatconj(quaternion1), quaternion2);

        angle = 2*acosd(z(1));

        tlabel1.Text = "Angle: " + angle;
    end
end