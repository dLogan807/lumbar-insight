# Lumbar Insight

## About

The aim of this project is to develop a UI to display, record, configure, and notify of real-time feedback on a subject carrying out a lifting task. As such, it could be utilised as a preventative measure for lumbosacral injury and act as an enabler for ease of further research. If successful, similar techniques could also be deployed on a wider scale to assist in physiotherapy or manual lifting jobs.

## Installation

Developed for use with [MATLAB 2024b](https://mathworks.com/downloads/).

Requires the following MATLAB add-ons:

- [Aerospace Toolbox](https://mathworks.com/products/aerospace-toolbox.html)
- [MATLAB Support Package for USB Webcams](https://au.mathworks.com/matlabcentral/fileexchange/45182-matlab-support-package-for-usb-webcams)
- [MATLAB Support Package for IP Cameras](https://au.mathworks.com/matlabcentral/fileexchange/49824-matlab-support-package-for-ip-cameras)

## Launching

1. Open the project with MATLAB
2. Run `launchLumbarInsight.m`

If the application does not launch, it is already open in another window. To override this behaviour, set `allowMultipleAppInstances` in `launchLumbarInsight.m` to true.

## Configuration

### Supported IMU Devices

- Shimmer 3
- Shimmer 2/2r

Support for further IMUs can be added by:

1. Implementing `IMUInterface.m`
2. Adding a value to the `DeviceTypes.m` enum
3. Modifying `connectDevice()` in `Model.m`

### Additional IMU Sampling Rates

Modify the `SamplingRates` array in the respective IMU's class (e.g. `shimmer/ShimmerIMU.m`).

### Changing Font Size

Adjust the `fontSize` variable in `LumbarInsight.m`.

### Modifying the Session Gradient Indicator

1. Open `views/SessionTabView.m`
2. Find `updateTrafficLightGraph()`
3. Modify as desired

To change colour boundaries, `upperMax` (amber), `upperWarn` (yellow), `standing` (green), `lowerWarn` (yellow), and `lowerMax` (amber) can be modified. Each represents the subject's lumbosacral angle at which a colour begins. Red is set at the minimum and maximum of the graph.\
`fullFlexionAngle` is the subject's calibrated full flexion angle. `decimalPercentage` is set through the slider on the Session tab, ranging from 0.0 (0%) to 1.0 (100%).

Colours (`red`,`green`,`yellow`,`amber`) can be in the range 0 to 1, where this is a gradient from red to green. To change the gradient itself, replace its colourmap in `CustomColourMaps.m`. For convenience, use jdherman's [colourmap generator](https://jdherman.github.io/colormap/).
