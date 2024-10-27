fig = uifigure('NumberTitle','off','MenuBar','none');
fig.Name = 'My Camera';

layout = uigridlayout( ...
    "Parent", fig, ...
    "RowHeight", {"1x", "1x"}, ...
    "ColumnWidth", {"1x", "1x"}, ...
    "Padding", 20, ...
    "ColumnSpacing", 40);

camera1 = webcam("USB2.0 HD UVC WebCam");

axes = uiaxes("Parent", layout);

frame = snapshot(camera1);
image1 = image(axes, zeros(size(frame),'uint8')); 
axis(axes,'image');

preview(camera1, image1)