{ A unit with constants used in the library tests }

unit TestConstants;

interface

uses
  Windows;
  
const
  DLL_PATH = '..\TestDLLs\TestDll.dll';
  DLL_NAME = '..\TestDLLs\TestDll.dll';  // The DLL/BPL names can be anything, but is best to
                                         // be the same as the path to the library
  BPL_PATH = '..\TestDLLs\TestBpl.bpl';
  BPL_NAME = '..\TestDLLs\TestBpl.bpl';
  BPL_DUPLICATE_UNIT_PATH = '..\TestDLLs\TestDuplicateUnitBpl.bpl';  // For testing the same unit contained in two packages

  TEST_FUNCTION_NAME = 'TestAdd';

  TEST_RES_NAME = 'TESTDATA';
  TEST_RES_TYPE = RT_RCDATA;
  TEST_RES_SIZE = 10;
  // A handle to a resource that is not valid and will be passed to LoadResource and SizeOfResource
  // This is a pointer, so it should not cause AVs
  TEST_WRONG_RES_HANDLE = 12345;
  // A resource type that doesn't exist in the test library and should not be found
  TEST_NONEXISTING_RES_TYPE = RT_FONT;

  TEST_WRONG_LIB_HANDLE = 12345;

implementation

end.
