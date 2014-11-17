unit TestmlBaseLoader;

interface

uses
  TestFramework,
  Windows,
  Classes,
  SysUtils,
  mlBaseLoader,
  mlTypes,
  TestConstants;

type
  // Test methods for class TSingleLoader
  TestTMlBaseLoader = class(TTestCase)
  private
    fMemStream: TMemoryStream;
    fMlBaseLoader: TMlBaseLoader;
    fEventCalled: Boolean;
    procedure LoadHelper(aPath: String);
    procedure TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aMemStream: TMemoryStream;
        var aFreeStream: Boolean);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLoadFromStreamValid;
    procedure TestLoadFromStreamInvalid;
    procedure TestLoadFromStreamEmpty;
    procedure TestGetFunctionAddressValid;
    procedure TestGetFunctionAddressInvalidName;
    procedure TestFindResourceValid;
    procedure TestFindResourceNonExistingName;
    procedure TestFindResourceNonExistingType;
    procedure TestLoadResourceValid;
    procedure TestLoadResourceValidCompareToWinapi;
    procedure TestLoadResourceInvalidByZeroHandle;
    procedure TestLoadResourceInvalidByWrongHandle;
    procedure TestSizeOfResourceValid;
    procedure TestSizeOfResourceValidCompareToWinapi;
    procedure TestSizeOfResourceInvalidByZeroHandle;
    procedure TestSizeOfResourceInvalidByWrongHandle;
    procedure TestOnDependencyLoadEvent;
  end;

implementation

procedure TestTMlBaseLoader.LoadHelper(aPath: String);
begin
  fMemStream.LoadFromFile(aPath);
  fMlBaseLoader.LoadFromStream(fMemStream);
end;

procedure TestTMlBaseLoader.SetUp;
begin
  SetCurrentDir('..\TestDLLs'); // So the test DLL/BPLs can be found

  fMemStream := TMemoryStream.Create;
  fMlBaseLoader := TMlBaseLoader.Create;
end;

procedure TestTMlBaseLoader.TearDown;
begin
  fMemStream.Free;
  fMlBaseLoader.Free;
end;

procedure TestTMlBaseLoader.TestLoadFromStreamValid;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  fMlBaseLoader.LoadFromStream(fMemStream);
end;

procedure TestTMlBaseLoader.TestLoadFromStreamInvalid;
var
  I: Cardinal;
begin
  // Try to load from an invalid stream filled with some data
  fMemStream.Size := 100000;
  Randomize;
  for I := 0 to fMemStream.Size - 1 do
    PByte(Cardinal(fMemStream.Memory) + I)^ := Byte(I);
  ExpectedException := EMlLibraryLoadError;
  fMlBaseLoader.LoadFromStream(fMemStream);
end;

procedure TestTMlBaseLoader.TestLoadFromStreamEmpty;
begin
  // Try to load from an empty strem
  fMemStream.Clear;
  ExpectedException := EMlLibraryLoadError;
  fMlBaseLoader.LoadFromStream(fMemStream);
end;

procedure TestTMlBaseLoader.TestGetFunctionAddressValid;
var
  ReturnValue: Pointer;
begin
  LoadHelper(DLL_PATH);
  ReturnValue := fMlBaseLoader.GetFunctionAddress(TEST_FUNCTION_NAME);
  CheckMethodIsNotEmpty(ReturnValue);
end;

procedure TestTMlBaseLoader.TestGetFunctionAddressInvalidName;
begin
  LoadHelper(DLL_PATH);
  ExpectedException := EMlProcedureError;
  fMlBaseLoader.GetFunctionAddress('Some invalid function name');
end;

procedure TestTMlBaseLoader.TestFindResourceValid;
var
  ResourceFound: HRSRC;
begin
  LoadHelper(DLL_PATH);
  ResourceFound := fMlBaseLoader.FindResourceMl(TEST_RES_NAME, TEST_RES_TYPE);
  CheckNotEquals(0, ResourceFound);
end;

procedure TestTMlBaseLoader.TestFindResourceNonExistingName;
var
  ResourceFound: HRSRC;
begin
  LoadHelper(DLL_PATH);
  ResourceFound := fMlBaseLoader.FindResourceMl('Res name that doesn''t exist in the lib', TEST_RES_TYPE);
  CheckEquals(0, ResourceFound);
end;

procedure TestTMlBaseLoader.TestFindResourceNonExistingType;
var
  ResourceFound: HRSRC;
begin
  LoadHelper(DLL_PATH);
  ResourceFound := fMlBaseLoader.FindResourceMl(TEST_RES_NAME, TEST_NONEXISTING_RES_TYPE);
  CheckEquals(0, ResourceFound);
end;

procedure TestTMlBaseLoader.TestLoadResourceValid;
var
  ResourceFound: HRSRC;
  ResourcePointer: THandle;
begin
  LoadHelper(DLL_PATH);
  ResourceFound := fMlBaseLoader.FindResourceMl(TEST_RES_NAME, TEST_RES_TYPE);
  ResourcePointer := fMlBaseLoader.LoadResourceMl(ResourceFound);
  CheckNotEquals(0, ResourcePointer);
end;

procedure TestTMlBaseLoader.TestLoadResourceValidCompareToWinapi;
var
  LibWin: THandle;
  ResourceFound, ResourceWin: HRSRC;
  ResourceHandle, ResourceHandleWin: THandle;
  ResourceSize: DWORD;
begin
  LoadHelper(DLL_PATH);
  ResourceFound := fMlBaseLoader.FindResourceMl(TEST_RES_NAME, TEST_RES_TYPE);
  ResourceHandle := fMlBaseLoader.LoadResourceMl(ResourceFound);
  ResourceSize := fMlBaseLoader.SizeOfResourceMl(ResourceFound);

  LibWin := LoadLibrary(DLL_PATH);
  ResourceWin := FindResource(LibWin, TEST_RES_NAME, TEST_RES_TYPE);
  ResourceHandleWin := LoadResource(LibWin, ResourceWin);

  CheckTrue(CompareMem(Pointer(ResourceHandle), Pointer(ResourceHandleWin), ResourceSize),
    'The raw resource content in memory should be the same as from the WinAPI');
end;

procedure TestTMlBaseLoader.TestLoadResourceInvalidByZeroHandle;
begin
  LoadHelper(DLL_PATH);
  ExpectedException := EMlResourceError;
  fMlBaseLoader.LoadResourceMl(0);
end;

procedure TestTMlBaseLoader.TestLoadResourceInvalidByWrongHandle;
begin
  LoadHelper(DLL_PATH);
  ExpectedException := EMlResourceError;
  fMlBaseLoader.LoadResourceMl(TEST_WRONG_RES_HANDLE);
end;

procedure TestTMlBaseLoader.TestSizeOfResourceValid;
var
  ResourceFound: HRSRC;
  ResourceSize: DWORD;
begin
  LoadHelper(DLL_PATH);
  ResourceFound := fMlBaseLoader.FindResourceMl(TEST_RES_NAME, TEST_RES_TYPE);
  ResourceSize := fMlBaseLoader.SizeOfResourceMl(ResourceFound);
  CheckEquals(TEST_RES_SIZE, ResourceSize);
end;

procedure TestTMlBaseLoader.TestSizeOfResourceValidCompareToWinapi;
var
  LibWin: THandle;
  ResourceFound, ResourceWin: HRSRC;
  ResourceSize, ResourceSizeWin: DWORD;
begin
  LoadHelper(DLL_PATH);
  ResourceFound := fMlBaseLoader.FindResourceMl(TEST_RES_NAME, TEST_RES_TYPE);
  ResourceSize := fMlBaseLoader.SizeOfResourceMl(ResourceFound);

  LibWin := LoadLibrary(DLL_PATH);
  ResourceWin := FindResource(LibWin, TEST_RES_NAME, TEST_RES_TYPE);
  ResourceSizeWin := SizeofResource(LibWin, ResourceWin);

  CheckEquals(ResourceSizeWin, ResourceSize, 'Windows API returned a different resource size');
end;

procedure TestTMlBaseLoader.TestSizeOfResourceInvalidByZeroHandle;
begin
  LoadHelper(DLL_PATH);
  ExpectedException := EMlResourceError;
  fMlBaseLoader.SizeOfResourceMl(0);
end;

procedure TestTMlBaseLoader.TestSizeOfResourceInvalidByWrongHandle;
begin
  LoadHelper(DLL_PATH);
  ExpectedException := EMlResourceError;
  fMlBaseLoader.SizeOfResourceMl(TEST_WRONG_RES_HANDLE);
end;

procedure TestTMlBaseLoader.TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
    aMemStream: TMemoryStream; var aFreeStream: Boolean);
begin
  fEventCalled := true;
end;

procedure TestTMlBaseLoader.TestOnDependencyLoadEvent;
begin    
  fMemStream.LoadFromFile(BPL_PATH_B);
  fMlBaseLoader.OnDependencyLoad := TestEvent;
  fMlBaseLoader.LoadFromStream(fMemStream);
  CheckTrue(fEventCalled, 'The OnDependencyLoad event was not called');
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTMlBaseLoader.Suite);

end.

