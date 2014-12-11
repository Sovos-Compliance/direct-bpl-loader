unit TestmlLibraryManager;

interface

uses
  TestFramework,
  Windows,
  Classes,
  SysUtils,
  mlLibrary,
  mlTypes,
  TestConstants;

type
  TestLibraryManager = class(TTestCase)
  private
    fMemStream: TMemoryStream;
    fEventCalled: Boolean;
    procedure TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aStream: TStream; var
        aFreeStream: Boolean);
    procedure TestEventLoadActionFromMem(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aStream:
        TStream; var aFreeStream: Boolean);
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

    procedure TestOnDependencyLoadEvent;

    procedure TestLoadPackageMem;
    procedure TestLoadPackageMemDuplicateFromDisk;
    procedure TestLoadPackageMemDuplicatePackageUnits;
    procedure TestLoadPackageMemRequiresB;
    procedure TestLoadPackageMemRequiresBFromMem;
    procedure TestEnumModules;
  end;

implementation

procedure TestLibraryManager.TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
    aStream: TStream; var aFreeStream: Boolean);
begin
  fEventCalled := true;
end;

procedure TestLibraryManager.TestEventLoadActionFromMem(const aLibName, aDependentLib: String; var aLoadAction:
    TLoadAction; var aStream: TStream; var aFreeStream: Boolean);
var
  SourceFile: String;
begin
  if aDependentLib = ExtractFileName(BPL_PATH_A) then
    SourceFile := BPL_PATH_A;
  if aDependentLib = ExtractFileName(BPL_PATH_B) then
    SourceFile := BPL_PATH_B;
  if aDependentLib = ExtractFileName(BPL_PATH_C) then
    SourceFile := BPL_PATH_C;
  if SourceFile <> '' then
  begin
    aLoadAction := laStream;
    aStream := TMemoryStream.Create;
    TMemoryStream(aStream).LoadFromFile(SourceFile);
  end;
end;

procedure TestLibraryManager.SetUp;
begin
  SetCurrentDir('..\TestDLLs'); // So the test DLL/BPLs can be found

  UnloadAllLibraries;  //VG: Reset the library loader and free the memory
  fMemStream := TMemoryStream.Create;
end;

procedure TestLibraryManager.TearDown;
begin
  UnloadAllLibraries;  //VG: Reset the library loader and free the memory
  fMemStream.Free;
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
  ReturnValue1 := LoadLibraryMem(fMemStream, DLL_PATH);
  ReturnValue2 := LoadLibraryMem(fMemStream, DLL_PATH);
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
type
  TTestProc = function(A, B: Integer): Integer;
var
  LibHandle: TLibHandle;
  TestProc: TTestProc;
  A, B, C: Integer;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibraryMem(fMemStream);
  @TestProc := GetProcAddressMem(LibHandle, TEST_FUNCTION_NAME);
  A := 2; B := 3;
  C := TestProc(A, B);
  CheckEquals(C, A + B);
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
  ReturnValue1 := LoadLibraryMem(fMemStream, DLL_PATH);
  ReturnValue2 := LoadLibraryMem(fMemStream, DLL_PATH);
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
  LibHandle := LoadLibraryMem(fMemStream, DLL_PATH);
  ReturnValue := GetModuleFileNameMem(LibHandle);
  CheckEquals(ReturnValue, ExtractFileName(DLL_PATH));
end;

procedure TestLibraryManager.TestGetModuleHandleMem;
var
  LibHandle: TLibHandle;
  ReturnValue: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibraryMem(fMemStream, DLL_PATH);
  ReturnValue := GetModuleHandleMem(DLL_PATH);
  CheckEquals(ReturnValue, LibHandle);
end;

procedure TestLibraryManager.TestOnDependencyLoadEvent;
begin
  MlSetOnLoadCallback(TestEvent);
  fEventCalled := false;
  fMemStream.LoadFromFile(BPL_PATH_B);
  LoadLibraryMem(fMemStream, BPL_PATH_B);
  CheckTrue(fEventCalled, 'The OnDependencyLoad event was not called');
end;

procedure TestLibraryManager.TestLoadPackageMem;
var
  TestClass: TPersistentClass;
begin
  fMemStream.LoadFromFile(BPL_PATH_A);
  LoadPackageMem(fMemStream, BPL_PATH_A);
  TestClass := GetClass(TEST_CLASS_NAME_A);
  CheckNotNull(TObject(TestClass), 'The class could not be loaded from the BPL. Check if project is built with Runtime packages');
end;

procedure TestLibraryManager.TestLoadPackageMemDuplicateFromDisk;
var
  Lib: HMODULE;
begin
  // Try to load the same package from disk with the standard API and from memory with the Mem one
  // This should raise an exception and not be allowed
  Lib := LoadPackage(BPL_PATH_A);
  try
    fMemStream.LoadFromFile(BPL_PATH_A);
    ExpectedException := EMlLibraryLoadError;
    LoadPackageMem(fMemStream, BPL_PATH_A);
  finally
    UnloadPackage(Lib);
  end;
end;

procedure TestLibraryManager.TestLoadPackageMemDuplicatePackageUnits;
begin
  // Try to load two packaged containing the same unit, which should raise an exception like done by LoadPackage
  ExpectedException := EPackageError;
  fMemStream.LoadFromFile(BPL_PATH_A);
  LoadPackageMem(fMemStream, BPL_PATH_A);
  fMemStream.LoadFromFile(BPL_DUPLICATE_UNIT_PATH);
  LoadPackageMem(fMemStream, BPL_DUPLICATE_UNIT_PATH);
end;

procedure TestLibraryManager.TestLoadPackageMemRequiresB;
var
  TestClass: TPersistentClass;
begin
  fMemStream.LoadFromFile(BPL_PATH_C);
  LoadPackageMem(fMemStream, BPL_PATH_C);
  TestClass := GetClass(TEST_CLASS_NAME_C);
  CheckNotNull(TObject(TestClass),
    Format('The "%s" class could not be loaded from the BPL. Check if project is built with Runtime packages', [TEST_CLASS_NAME_C]));
end;

procedure TestLibraryManager.TestLoadPackageMemRequiresBFromMem;
var
  TestClass: TPersistentClass;
begin
  MlSetOnLoadCallback(TestEventLoadActionFromMem);
  fMemStream.LoadFromFile(BPL_PATH_C);
  LoadPackageMem(fMemStream, BPL_PATH_C);
  TestClass := GetClass(TEST_CLASS_NAME_C);
  CheckNotNull(TObject(TestClass),
    Format('The "%s" class could not be loaded from the BPL. Check if project is built with Runtime packages', [TEST_CLASS_NAME_C]));
end;

// Helper callback function for the TestEnumModules test
function EnumModule(HInstance: Integer; Data: Pointer): Boolean;
var
  ModName : string;
  Len : Cardinal;
begin
  SetLength (ModName, MAX_PATH + 1);
  Len := MAX_PATH;
  SetLength (ModName, GetModuleFileName(HInstance, PChar(ModName), Len));
  Result := True;
end;

procedure TestLibraryManager.TestEnumModules;
begin
  EnumModules(EnumModule, nil);
  fMemStream.LoadFromFile(BPL_PATH_A);
  LoadPackageMem(fMemStream, BPL_PATH_A);
  EnumModules(EnumModule, nil);
  // No need to check conditions at the moment. EnumModule should be able to list all modules and get their names without exceptions
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestLibraryManager.Suite);

end.
