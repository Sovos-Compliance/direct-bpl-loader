unit TestmlLibraryManager;

interface

uses
  TestFramework,
  Windows, Classes,
  mlLibraryManager,
  mlTypes,
  TestConstants;

type
  TestLibraryManager = class(TTestCase)
  private
    fMemStream: TMemoryStream;
    fEventCalled: Boolean;
    procedure TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aMemStream: TMemoryStream);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLoadLibraryMemValid;
    procedure TestLoadLibraryMemInvalidStream;
    procedure TestLoadLibraryMemEmptyStream;
    procedure TestLoadLibraryTwiceNamed;
    procedure TestLoadLibraryTwiceUnnamed;
    procedure TestGetProcAddressMemValid;
    procedure TestGetProcAddressMemInvalidName;
    procedure TestFindResourceValid;
    procedure TestFreeLibraryMemValid;
    procedure TestFreeLibraryMemInvalidHandle;
    procedure TestFreeLibraryTwiceNamed;
    procedure TestGetModuleFileNameMem;
    procedure TestGetModuleHandleMem;

    procedure TestLoadPackageMem;

    procedure TestOnDependencyLoadEvent;
  end;

implementation

procedure TestLibraryManager.SetUp;
begin
  UnloadAllLibrariesMem;  //VG: Reset the library loader and free the memory
  fMemStream := TMemoryStream.Create;
end;

procedure TestLibraryManager.TearDown;
begin
  UnloadAllLibrariesMem;  //VG: Reset the library loader and free the memory
  fMemStream.Free;
end;

procedure TestLibraryManager.TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
    aMemStream: TMemoryStream);
begin
  fEventCalled := true;
end;

procedure TestLibraryManager.TestLoadLibraryMemValid;
var
  ReturnValue: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue := LoadLibraryMem(fMemStream);
  CheckNotEquals(0, ReturnValue, 'Library should have been loaded');
end;

procedure TestLibraryManager.TestLoadLibraryMemInvalidStream;
var
  I: Cardinal;
  ReturnValue: TLibHandle;
begin
  // Try to load from an invalid stream filled with some data
  fMemStream.Size := 100000;
  Randomize;
  for I := 0 to fMemStream.Size - 1 do
    PByte(Cardinal(fMemStream.Memory) + I)^ := Byte(I);

  ExpectedException := EMLLibraryLoadError;
  ReturnValue := LoadLibraryMem(fMemStream);
  CheckEquals(0, ReturnValue, 'An invalid library should not be loaded');
end;

procedure TestLibraryManager.TestLoadLibraryMemEmptyStream;
var
  ReturnValue: TLibHandle;
begin
  // Try to load from an empty strem
  fMemStream.Clear;
  ExpectedException := EMLLibraryLoadError;
  ReturnValue := LoadLibraryMem(fMemStream);
  CheckEquals(0, ReturnValue, 'An empty stream should not be loaded');
end;

procedure TestLibraryManager.TestLoadLibraryTwiceNamed;
var
  ReturnValue1, ReturnValue2: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue1 := LoadLibraryMem(fMemStream, DLL_NAME);
  ReturnValue2 := LoadLibraryMem(fMemStream, DLL_NAME);
  CheckEquals(ReturnValue1, ReturnValue2, 'Library handles should be the same because it is loaded once with RefCount 2');
end;

procedure TestLibraryManager.TestLoadLibraryTwiceUnnamed;
var
  ReturnValue1, ReturnValue2: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue1 := LoadLibraryMem(fMemStream);
  ReturnValue2 := LoadLibraryMem(fMemStream);
  CheckNotEquals(ReturnValue1, ReturnValue2, 'Library handles should be different because no lib names are passed');
end;

procedure TestLibraryManager.TestGetProcAddressMemValid;
var
  LibHandle: TLibHandle;
  ReturnValue: Pointer;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibraryMem(fMemStream);
  ReturnValue := GetProcAddressMem(LibHandle, TEST_FUNCTION_NAME);
  CheckMethodIsNotEmpty(ReturnValue);
end;

procedure TestLibraryManager.TestGetProcAddressMemInvalidName;
var
  LibHandle: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibraryMem(fMemStream);
  ExpectedException := EMlProcedureError;
  GetProcAddressMem(LibHandle, 'Some invalid function name');
end;

procedure TestLibraryManager.TestFindResourceValid;
var
  LibHandle: TLibHandle;
  ResourceFound: HRSRC;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibraryMem(fMemStream);
  ResourceFound := FindResourceMem(LibHandle, TEST_RES_NAME, TEST_RES_TYPE);
  CheckNotEquals(0, ResourceFound);
end;

procedure TestLibraryManager.TestFreeLibraryMemValid;
var
  LibHandle: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibraryMem(fMemStream);
  FreeLibraryMem(LibHandle);
end;

procedure TestLibraryManager.TestFreeLibraryMemInvalidHandle;
begin
  ExpectedException := EMlInvalidHandle;
  FreeLibraryMem(TEST_WRONG_LIB_HANDLE);
end;

procedure TestLibraryManager.TestFreeLibraryTwiceNamed;
var
  ReturnValue1, ReturnValue2: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue1 := LoadLibraryMem(fMemStream, DLL_NAME);
  ReturnValue2 := LoadLibraryMem(fMemStream, DLL_NAME);
  FreeLibraryMem(ReturnValue1);
  FreeLibraryMem(ReturnValue2);
  // The RefCount of the library should be 2 so it can be freed twice without raising an exception
end;

procedure TestLibraryManager.TestGetModuleFileNameMem;
var
  LibHandle: TLibHandle;
  ReturnValue: String;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibraryMem(fMemStream, DLL_NAME);
  ReturnValue := GetModuleFileNameMem(LibHandle);
  CheckEquals(ReturnValue, DLL_NAME);
end;

procedure TestLibraryManager.TestGetModuleHandleMem;
var
  LibHandle: TLibHandle;
  ReturnValue: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibraryMem(fMemStream, DLL_NAME);
  ReturnValue := GetModuleHandleMem(DLL_NAME);
  CheckEquals(ReturnValue, LibHandle);
end;

procedure TestLibraryManager.TestLoadPackageMem;
var
  TestClass: TPersistentClass;
begin
  fMemStream.LoadFromFile(BPL_PATH);
  LoadPackageMem(fMemStream, 'TestBPL');
  TestClass := GetClass('TButtonReload');
  CheckNotNull(TObject(TestClass), 'The class could not be loaded from the BPL. Check if project is built with Runtime packages');
end;

procedure TestLibraryManager.TestOnDependencyLoadEvent;
begin
  MlOnDependencyLoad := TestEvent;
  fEventCalled := false;
  fMemStream.LoadFromFile(DLL_PATH);
  LoadLibraryMem(fMemStream, DLL_NAME);
  CheckTrue(fEventCalled, 'The OnDependencyLoad event was not called');
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestLibraryManager.Suite);

end.
