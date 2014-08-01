{*******************************************************************************
*  Created by Vladimir Georgiev, 2014                                          *
*                                                                              *
*  Description:                                                                *
*  Unit providing several methods to load and use a DLL/BPL library from       *
*  memory instead of a file. The methods are named after the original WinAPIs  *
*  like LoadLibrary, FreeLibrary, GetProcAddress, etc, but with a Mem suffix.  *
*  Same for LoadPackage and UnloadPackage for working with BPLs                *
*  The underlying functionality is provided by the hidden TMlLibraryManager    *
*  class that manages the loading, unloading, reference counting, generation of*
*  handles, etc. It uses the TMlBaseLoader for the loading/unloading of libs.  *
*                                                                              *
*******************************************************************************}

unit mlLibraryManager;

interface

uses
  SysUtils,
  Classes,
  SysConst,
  Windows,
  mlTypes,
  mlBaseLoader,
  mlBPLLoader;


// DLL loading functions. They only forward the calls to the TMlLibraryManager instance
function LoadLibraryMem(aSource: TMemoryStream; aLibFileName: String = ''): TLibHandle;
procedure FreeLibraryMem(hModule: TLibHandle);
function GetProcAddressMem(hModule: TLibHandle; lpProcName: LPCSTR): FARPROC;
function FindResourceMem(hModule: TLibHandle; lpName, lpType: PChar): HRSRC;
function LoadResourceMem(hModule: TLibHandle; hResInfo: HRSRC): HGLOBAL;
function SizeofResourceMem(hModule: TLibHandle; hResInfo: HRSRC): DWORD;
function GetModuleFileNameMem(hModule: TLibHandle): String;
function GetModuleHandleMem(ModuleName: String): TLibHandle;

/// BPL loading functions
function LoadPackageMem(aSource: TMemoryStream; aLibFileName: String): TLibHandle;
procedure UnloadPackage(Module: TLibHandle);

//TODO VG 090714: This method is used only to reset the loader during unit testing. Can be removed
{$IFDEF _CONSOLE_TESTRUNNER}
procedure UnloadAllLibrariesMem;
{$ENDIF}

var
  MlOnDependencyLoad: TMlLoadDependentLibraryEvent;

implementation

const
  BASE_HANDLE = $1;  // The minimum value where the allocation of TLibHandle values begins

type
  TMlLibraryManager = class
  private
    fCrit: TRTLCriticalSection;
    fLibs: TList;
    function GetLibs(aIndex: Integer): TMlBaseLoader;
    function GetNewHandle: TLibHandle;
    function LibraryIndexByHandle(aHandle: TLibHandle): Integer;
    function LibraryIndexByName(aName: String): Integer;
    procedure DoDependencyLoad(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aMemStream:
        TMemoryStream);
    property Libs[aIndex: Integer]: TMlBaseLoader read GetLibs;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadLibrary(aSource: TMemoryStream; aLibFileName: String): TLibHandle;
    procedure FreeLibrary(aHandle: TLibHandle);
    function GetProcAddress(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC;
    function FindResource(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC;
    function LoadResource(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL;
    function SizeofResource(aHandle: TLibHandle; hResInfo: HRSRC): DWORD;
    function GetModuleFileName(aHandle: TLibHandle): String;
    function GetModuleHandle(aModuleName: String): TLibHandle;
    function LoadPackage(aSource: TMemoryStream; aLibFileName: String): TLibHandle;
    procedure UnloadPackage(aHandle: TLibHandle);
  end;

var
  Manager: TMlLibraryManager;

{ DLL Library memory functions }

function LoadLibraryMem(aSource: TMemoryStream; aLibFileName: String = ''): TLibHandle;
begin
  Result := Manager.LoadLibrary(aSource, aLibFileName);
end;

procedure FreeLibraryMem(hModule: TLibHandle);
begin
  Manager.FreeLibrary(hModule);
end;

function GetProcAddressMem(hModule: TLibHandle; lpProcName: LPCSTR): FARPROC;
begin
  Result := Manager.GetProcAddress(hModule, lpProcName);
end;

function FindResourceMem(hModule: TLibHandle; lpName, lpType: PChar): HRSRC;
begin
  Result := Manager.FindResource(hModule, lpName, lpType);
end;

function LoadResourceMem(hModule: TLibHandle; hResInfo: HRSRC): HGLOBAL;
begin
  Result := Manager.LoadResource(hModule, hResInfo);
end;

function SizeofResourceMem(hModule: TLibHandle; hResInfo: HRSRC): DWORD;
begin
  Result := Manager.SizeofResource(hModule, hResInfo);
end;

function GetModuleFileNameMem(hModule: TLibHandle): String;
begin
  Result := Manager.GetModuleFileName(hModule);
end;

function GetModuleHandleMem(ModuleName: String): TLibHandle;
begin
  Result := Manager.GetModuleHandle(ModuleName);
end;

{ BPL Library memory functions }

function LoadPackageMem(aSource: TMemoryStream; aLibFileName: String): TLibHandle;
begin
  Result := Manager.LoadPackage(aSource, aLibFileName);
end;

procedure UnloadPackage(Module: TLibHandle);
begin
  Manager.UnloadPackage(Module);
end;

//TODO VG 090714: This method is used only to reset the manager during unit testing. Can be removed
{$IFDEF _CONSOLE_TESTRUNNER}
procedure UnloadAllLibrariesMem;
begin
  Manager.Free;
  Manager := TMlLibraryManager.Create;
end;
{$ENDIF}

{ TMlLibraryManager }

function TMlLibraryManager.GetLibs(aIndex: Integer): TMlBaseLoader;
begin
  if (aIndex < 0) or (aIndex >= fLibs.Count) then
    raise Exception.Create('Library index out of bounds');
  Result := fLibs[aIndex];
end;

/// Generate a unique handle that will be returned as a library identifier
function TMlLibraryManager.GetNewHandle: TLibHandle;
var
  I: Integer;
  Unique: Boolean;
begin
  Result := BASE_HANDLE;
  repeat
    Unique := true;
    for I := 0 to fLibs.Count - 1 do
      if TMlBaseLoader(fLibs[I]).Handle = Result then
      begin
        Unique := false;
        Inc(Result);
        Break;
      end;
  until Unique;
end;

/// Helper method to find the internal index of a loaded library given its handle
/// Used by most other methods that operate on a handle
function TMlLibraryManager.LibraryIndexByHandle(aHandle: TLibHandle): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to fLibs.Count - 1 do
    if Libs[I].Handle = aHandle then
    begin
      Result := I;
      Exit;
    end;
end;

/// Helper method to find the internal index of a loaded library given its handle
/// Used when loading a library to check if loaded already
function TMlLibraryManager.LibraryIndexByName(aName: String): Integer;
var
  I: Integer;
begin
  Result := -1;
  if aName = '' then
    Exit;
  for I := 0 to fLibs.Count - 1 do
    if SameText(Libs[I].Name, aName) then
    begin
      Result := I;
      Exit;
    end;
end;

/// This method is assigned to each TmlBaseLoader and forwards the event to the global MlOnDependencyLoad procedure if one is assigned
procedure TMlLibraryManager.DoDependencyLoad(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
    aMemStream: TMemoryStream);
begin
  if Assigned(MlOnDependencyLoad) then
    MlOnDependencyLoad(aLibName, aDependentLib, aLoadAction, aMemStream);
end;

constructor TMlLibraryManager.Create;
begin
  inherited;
  fLibs := TList.Create;
  InitializeCriticalSection(fCrit);
end;

destructor TMlLibraryManager.Destroy;
var
  I: Integer;
begin
  for I := fLibs.Count - 1 downto 0 do
    Libs[I].Free;
  fLibs.Free;
  DeleteCriticalSection(fCrit);
  inherited;
end;

/// LoadLibraryMem: aName is compared to the loaded libraries and if found the
/// reference count is incremented. If the aName is empty or not found the library is loaded
function TMlLibraryManager.LoadLibrary(aSource: TMemoryStream; aLibFileName: String): TLibHandle;
var
  Loader: TMlBaseLoader;
  Index: Integer;
begin
  Result := 0;
  EnterCriticalSection(fCrit);
  try
    Index := LibraryIndexByName(aLibFileName);
    if Index <> -1 then
    begin
      // Increase the RefCount of the already loaded library
      Libs[Index].RefCount := Libs[Index].RefCount + 1;
      Result := Libs[Index].Handle;
    end else
    begin
      // Or load the library if it is a new one
      Loader := TMlBaseLoader.Create;
      try
        Loader.OnDependencyLoad := DoDependencyLoad;
        Loader.LoadFromStream(aSource);
        Loader.Handle := GetNewHandle;
        Loader.Name := aLibFileName;
        Loader.RefCount := 1;
        fLibs.Add(Loader);
        Result := Loader.Handle;
      except
        Loader.Free;
        raise;
      end;
    end;
  finally
    LeaveCriticalSection(fCrit);
  end;
end;

/// Decrement the RefCount of a library on each call and unload/free it if the count reaches 0
procedure TMlLibraryManager.FreeLibrary(aHandle: TLibHandle);
var
  Index: Integer;
begin
  EnterCriticalSection(fCrit);
  try
    Index := LibraryIndexByHandle(aHandle);
    if Index <> -1 then
    begin
      Libs[Index].RefCount := Libs[Index].RefCount - 1;
      if Libs[Index].RefCount = 0 then
      begin
        Libs[Index].Free;
        fLibs.Delete(Index);
      end;
    end
    else
      raise EMlInvalidHandle.Create('Invalid library handle');
  finally
    LeaveCriticalSection(fCrit);
  end;
end;

function TMlLibraryManager.GetProcAddress(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].GetFunctionAddress(lpProcName)
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.FindResource(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].FindResource(lpName, lpType)
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.LoadResource(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].LoadResource(hResInfo)
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.SizeofResource(aHandle: TLibHandle; hResInfo: HRSRC): DWORD;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].SizeOfResource(hResInfo)
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.GetModuleFileName(aHandle: TLibHandle): String;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].Name
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.GetModuleHandle(aModuleName: String): TLibHandle;
var
  Index: Integer;
begin
  Index := LibraryIndexByName(aModuleName);
  if Index <> -1 then
    Result := Libs[Index].Handle
  else
    Result := 0;
end;

/// Function to emulate the LoadPackage from a stream
/// Source is taken from the original Delphi RTL functions LoadPackage, InitializePackage in SysUtils
function TMlLibraryManager.LoadPackage(aSource: TMemoryStream; aLibFileName: String): TLibHandle;
var
  Loader: TBPLLoader;
  Index: Integer;
begin
  Result := 0;
  EnterCriticalSection(fCrit);
  try
    Index := LibraryIndexByName(aLibFileName);
    if Index <> -1 then
    begin
      // Increase the RefCount of the already loaded library
      Libs[Index].RefCount := Libs[Index].RefCount + 1;
      Result := Libs[Index].Handle;
    end else
    begin
      // Or load the library if it is a new one
      Loader := TBPLLoader.Create;
      try
        // For BPLs the handle must be assigned and added to the list before LoadFromStream
        // due to the internal checking of BPL dependencies in TMlBPLLoader.CheckForDuplicateUnits,
        // which relies on this handle (calling GetModuleHandleMem)
        Loader.Handle := GetNewHandle;
        Loader.RefCount := 1;
        Loader.OnDependencyLoad := DoDependencyLoad;
        fLibs.Add(Loader);
        Loader.LoadFromStream(aSource, aLibFileName);
        Result := Loader.Handle;
      except
        fLibs.Remove(Loader);
        Loader.Free;
        raise;
      end;
    end;
  finally
    LeaveCriticalSection(fCrit);
  end;
end;

procedure TMlLibraryManager.UnloadPackage(aHandle: TLibHandle);
var
  Index: Integer;
begin
  EnterCriticalSection(fCrit);
  try
    Index := LibraryIndexByHandle(aHandle);
    if Index <> -1 then
    begin
      Libs[Index].RefCount := Libs[Index].RefCount - 1;
      if Libs[Index].RefCount = 0 then
      begin
        Libs[Index].Free;
        fLibs.Delete(Index);
      end;
    end
    else
      raise EMlInvalidHandle.Create('Invalid library handle');
  finally
    LeaveCriticalSection(fCrit);
  end;
end;

initialization
  Manager := TMlLibraryManager.Create;

finalization
  Manager.Free;

end.
