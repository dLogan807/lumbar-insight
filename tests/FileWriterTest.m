classdef FileWriterTest < matlab.unittest.TestCase

    properties
        fileWriter FileWriter
    end
    
    methods(TestClassSetup)
        
    end
    
    methods(TestMethodSetup)
        % Setup for each test
        function createFileWriter(testCase)
            testCase.fileWriter = FileWriter("data");
        end

        function closeFile(testCase)
            if (testCase.fileWriter.FileInitialised)
                testCase.fileWriter.closeFile(["","","",""]);
            end
        end

        function deleteDataFolder(~)
            if (exist("data", "dir") == 7)
                rmdir("data", "s");
            end
        end
    end
    
    methods(Test)
        % Test methods
        
        function dataFolderCreatedTest(testCase)
            testCase.fileWriter.initialiseNewFile();
            testCase.fileWriter.closeFile(["","","",""]);
            actual = exist("data", "dir");
            expected = 7;
            testCase.verifyEqual(actual,expected);
        end

        function initialiseNewFileTest(testCase)
            testCase.fileWriter.initialiseNewFile();
            folderContents = dir("data");
            folderNotEmpty = numel(folderContents) > 2;
            testCase.verifyTrue(folderNotEmpty);
        end

        function initialiseNewFileTwiceTest(testCase)
            testCase.fileWriter.initialiseNewFile();
            testCase.verifyError(@()testCase.fileWriter.initialiseNewFile(), "initialiseNewFile:FileAlreadyInitialised");
        end

        function writeAngleDataNotInitialised(testCase)
            testCase.verifyError(@()testCase.fileWriter.writeAngleData(["","","",""]), "writeAngleData:FileNotInitialised");
        end

        function closeFileNotInitialised(testCase)
            testCase.verifyError(@()testCase.fileWriter.closeFile(["","","",""]), "closeFile:FileNotInitialised");
        end
    end
    
end