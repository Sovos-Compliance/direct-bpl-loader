{ A unit with constants used in the library tests }

unit TestConstants;

interface

uses
  Windows;

const
  DLL_PATH   = '..\TestDLLs\TestDll.dll';
  BPL_PATH_A = '..\TestDLLs\TestBplA.bpl';
  BPL_PATH_B = '..\TestDLLs\TestBplB_ReqA.bpl';  // For testing package dependencies
  BPL_PATH_C = '..\TestDLLs\TestBplC_ReqB.bpl';  // For testing package dependencies
  BPL_DUPLICATE_UNIT_PATH = '..\TestDLLs\TestBplDuplicateUnit.bpl';  // For testing the same unit contained in two packages

  TEST_CLASS_NAME_A = 'TTestClassA';
  TEST_CLASS_NAME_B = 'TTestClassB';
  TEST_CLASS_NAME_C = 'TTestClassC';

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
