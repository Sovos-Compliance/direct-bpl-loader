unit TestmlLibraryManagerHooked;

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
  TestLibraryManagerHooked = class(TTestCase)
  private
    fMemStream: TMemoryStream;
    fEventCalled: Boolean;
    procedure TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aMemStream: TMemoryStream;
        var aFreeStream: Boolean);
    procedure TestEventLoadActionFromMem(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
        aMemStream: TMemoryStream; var aFreeStream: Boolean);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLoadLibraryValid;
    procedure TestLoadPackage;
  end;

implementation

procedure TestLibraryManagerHooked.TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
    aMemStream: TMemoryStream; var aFreeStream: Boolean);
begin
  fEventCalled := true;
end;

procedure TestLibraryManagerHooked.SetUp;
begin
  SetCurrentDir('..\TestDLLs'); // So the test DLL/BPLs can be found

  UnloadAllLibraries;  //VG: Reset the library loader and free the memory
  fMemStream := TMemoryStream.Create;
end;

procedure TestLibraryManagerHooked.TearDown;
begin
  UnloadAllLibraries;  //VG: Reset the library loader and free the memory
  fMemStream.Free;
end;

procedure TestLibraryManagerHooked.TestEventLoadActionFromMem(const aLibName, aDependentLib: String; var aLoadAction:
    TLoadAction; var aMemStream: TMemoryStream; var aFreeStream: Boolean);
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
    aLoadAction := laMemStream;
    aMemStream := TMemoryStream.Create;
    aMemStream.LoadFromFile(SourceFile);
  end;
end;

procedure TestLibraryManagerHooked.TestLoadLibraryValid;
var
  ReturnValue: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue := LoadLibrary(fMemStream);
  CheckNotEquals(0, ReturnValue, 'Library should have been loaded');
end;

procedure TestLibraryManagerHooked.TestLoadPackage;
var
  TestClass: TPersistentClass;
begin
  fMemStream.LoadFromFile(BPL_PATH_A);
  LoadPackage(fMemStream, BPL_PATH_A);
  TestClass := GetClass(TEST_CLASS_NAME_A);
  CheckNotNull(TObject(TestClass), 'The class could not be loaded from the BPL. Check if project is built with Runtime packages');
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestLibraryManagerHooked.Suite);

end.
