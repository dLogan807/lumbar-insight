classdef ShimmerIMUTest < matlab.unittest.TestCase

    properties
        shimmerIMU ShimmerIMU
    end
    
    methods(TestClassSetup)
        function createShimmer(testCase)
            testCase.shimmerIMU = ShimmerIMU("test");
        end
    end
    
    methods(TestMethodSetup)
        % Setup for each test
    end
    
    methods(Test)
        % Test methods
        
        function isConnectedTest(testCase)
           actual = testCase.shimmerIMU.IsConnected();
           expected = false;
           testCase.verifyEqual(actual,expected);
        end

        function isConfiguredTest(testCase)
           actual = testCase.shimmerIMU.IsConfigured();
           expected = false;
           testCase.verifyEqual(actual,expected);
        end

        function isStreamingTest(testCase)
           actual = testCase.shimmerIMU.IsStreaming();
           expected = false;
           testCase.verifyEqual(actual,expected);
        end

        function batteryInfoTest(testCase)
            actual = testCase.shimmerIMU.BatteryInfo;
            expected = "Not connected. No battery information.";
            testCase.verifyEqual(actual,expected);
        end

        function latestQuaternionTest(testCase)
            testCase.verifyError(@()testCase.shimmerIMU.LatestQuaternion, "LatestQuaternion:DeviceNotConnected");
        end

        function configureTest(testCase)
            testCase.verifyError(@()testCase.shimmerIMU.configure(20), "configure:DeviceNotConnected");
        end

        function samplingRateTest(testCase)
            testCase.verifyError(@()testCase.shimmerIMU.setSamplingRate(20), "setSamplingRate:DeviceNotConnected");
        end

        function startStreamingTest(testCase)
            actual = testCase.shimmerIMU.startStreaming();
            expected = false;
            testCase.verifyEqual(actual,expected);
        end

        function stopStreamingTest(testCase)
            actual = testCase.shimmerIMU.stopStreaming();
            expected = true;
            testCase.verifyEqual(actual,expected);
        end
    end
    
end