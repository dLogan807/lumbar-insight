classdef ModelTest < matlab.unittest.TestCase
    properties
        model Model
    end
    
    methods(TestClassSetup)
        function deleteDataFolder(~)
            if (exist("data", "dir") == 7)
                rmdir("data", "s");
            end
        end
    end
    
    methods(TestMethodSetup)
        function setupModel(testCase)
            testCase.model = Model();
        end
    end
    
    methods(Test)
        % Test methods
        function dataFolderCreatedTest(testCase)
            actual = exist("data", "dir");
            expected = 7;
            testCase.verifyEqual(actual,expected)
        end

        function addTimeStreamingNotStreamingTest(testCase)
            testCase.model.addTimeStreaming(123);
            bothValuesZero = (testCase.model.TimeStreaming == 0) && (testCase.model.TimeRecording == 0);
            testCase.assertTrue(bothValuesZero);
        end

        function addTimeAboveThresholdNotStreamingTest(testCase)
            testCase.model.addTimeAboveThreshold(12.5);
            bothValuesZero = (testCase.model.TimeAboveThreshold == 0) && (testCase.model.RecordedTimeAboveThreshold == 0);
            testCase.assertTrue(bothValuesZero);
        end

        function getPollingRateNotConfiguredTest(testCase)
            actual = testCase.model.getPollingRate();
            expected = -1;
            testCase.verifyEqual(actual,expected);
        end

        function getPollingRateOverrideOnTest(testCase)
            testCase.model.PollingRateOverride = 10;
            testCase.model.PollingOverrideEnabled = true;
            actual = testCase.model.getPollingRate();
            expected = 10;
            testCase.verifyEqual(actual,expected);
        end

        function setThresholdValuesDecimalNotCalibratedTest(testCase)
            testCase.model.setThresholdValues(90.5);
            decimalThresholdSet = testCase.model.DecimalThresholdPercentage == 0.905;
            thresholdAngleEmpty = isempty(testCase.model.ThresholdAngle);
            testCase.assertTrue(decimalThresholdSet && thresholdAngleEmpty);
        end

        function updateCeilingAnglesNotConfiguredTest(testCase)
            testCase.model.updateCeilingAngles(10);
            allAnglesEmpty = (isempty(testCase.model.LargestStreamedAngle) ...
                && isempty(testCase.model.SmallestStreamedAngle) ...
                && isempty(testCase.model.SmallestRecordedAngle) ...
                && isempty(testCase.model.LargestRecordedAngle));
            testCase.verifyTrue(allAnglesEmpty);
        end

        function latestAngleNotConfiguredTest(testCase)
            testCase.verifyError(@()testCase.model.LatestAngle, "LatestAngle:IMUNotConnected");
        end

        function latestCalibratedAngleNotConfiguredTest(testCase)
            testCase.verifyError(@()testCase.model.LatestCalibratedAngle, "LatestCalibratedAngle:NotCalibrated");
        end

        function bothIMUDevicesConnectedTest(testCase)
            actual = testCase.model.bothIMUDevicesConnected();
            expected = false;
            testCase.verifyEqual(actual,expected);
        end

        function bothIMUDevicesConfiguredTest(testCase)
            actual = testCase.model.bothIMUDevicesConfigured();
            expected = false;
            testCase.verifyEqual(actual,expected);
        end

        function bothIMUDevicesStreamingTest(testCase)
            actual = testCase.model.bothIMUDevicesStreaming();
            expected = false;
            testCase.verifyEqual(actual,expected);
        end

        function calibrationCompletedTest(testCase)
            actual = testCase.model.calibrationCompleted();
            expected = false;
            testCase.verifyEqual(actual,expected);
        end

    end
    
end