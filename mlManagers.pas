{*******************************************************************************
*  Created by Vladimir Georgiev, 2014                                          *
*                                                                              *
*  Description:                                                                *
*  Unit providing several methods to load and use a DLL/BPL library from       *
*  memory instead of a file. The methods are named after the original WinAPIs  *
*  like LoadLibrary, FreeLibrary, GetProcAddress, etc, but with a Mem suffix   *
*  for the Unhooked version and without a suffix for the Hooked version.       *
*  Same for LoadPackage and UnloadPackage for working with BPLs                *
*  The underlying functionality is provided by the TMlLibraryManager           *
*  class that manages the loading, unloading, reference counting, generation of*
*  handles, etc. It uses the TMlBaseLoader for the loading/unloading of libs.  *
*                                                                              *
*******************************************************************************}

{$I APIMODE.INC}

unit mlManagers;

interface

uses
  SysUtils,
  Classes,
  SysConst,
  Windows,
  TlHelp32,
  JclPeImage,
  mlTypes,
  mlBaseLoader,
  mlBPLLoader;

type
  TMlLibraryManager = class
  private
    fCrit: TRTLCriticalSection;
    fLibs: TList;
    fOnDependencyLoad: TMlLoadDependentLibraryEvent;
    function GetLibs(aIndex: Integer): TMlBaseLoader;
    function GetNewHandle: TLibHandle;
    function LibraryIndexByHandle(aHandle: TLibHandle): Integer;
    function LibraryIndexByName(aName: String): Integer;
    procedure DoDependencyLoad(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aMemStream:
        TMemoryStream; var aFreeStream: Boolean);
    property Libs[aIndex: Integer]: TMlBaseLoader read GetLibs;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadLibraryMl(aSource: TMemoryStream; aLibFileName: String): TLibHandle; virtual;
    procedure FreeLibraryMl(aHandle: TLibHandle); virtual;
    function GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC; virtual;
    function FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC; virtual;
    function LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL; virtual;
    function SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD; virtual;
    function GetModuleFileNameMl(aHandle: TLibHandle): String; virtual;
    function GetModuleHandleMl(aModuleName: String): TLibHandle; virtual;

    function LoadPackageMl(aSource: TMemoryStream; aLibFileName: String; aValidatePackage: TValidatePackageProc):
        TLibHandle;
    procedure UnloadPackageMl(aHandle: TLibHandle);
    property OnDependencyLoad: TMlLoadDependentLibraryEvent read fOnDependencyLoad write fOnDependencyLoad;
  end;

{$IFDEF MLHOOKED}
  TMlHookedLibraryManager = class(TMlLibraryManager)
  private
    fHooks: TJclPeMapImgHooks;
    fLoadLibraryOrig      : TLoadLibraryFunc;
    fFreeLibraryOrig      : TFreeLibraryFunc;
    fGetProcAddressOrig   : TGetProcAddressFunc;
    fFindResourceOrig     : TFindResourceFunc;
    fLoadResourceOrig     : TLoadResourceFunc;
    fSizeofResourceOrig   : TSizeofResourceFunc;
    fGetModuleFileNameOrig: TGetModuleFileNameFunc;
    fGetModuleHandleOrig  : TGetModuleHandleFunc;

    fWinHandles: array of Cardinal;

    /// <summary>Read the handles and filename of all libraries loaded by Windows. The method is called
    /// only when the Manager object is created</summary>
    procedure ReadLoadedLibs;
    procedure HookAPIs;
    function IsWinHandle(aHandle: TLibHandle): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadLibraryMl(lpLibFileName: PChar): TLibHandle; overload;
    function LoadLibraryMl(aSource: TMemoryStream; aLibFileName: String): TLibHandle; overload; override;
    procedure FreeLibraryMl(aHandle: TLibHandle); override;
    function GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC; override;
    function FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC; override;
    function LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL; override;
    function SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD; override;
    function GetModuleFileNameMl(aHandle: TLibHandle): String; override;
    function GetModuleHandleMl(aModuleName: String): TLibHandle; override;
  end;
{$ENDIF MLHOOKED}

var
{$IFDEF MLHOOKED}
  Manager: TMlHookedLibraryManager;
{$ELSE}
  Manager: TMlLibraryManager;
{$ENDIF MLHOOKED}

implementation

const
  BASE_HANDLE = $1;  // The minimum value where the allocation of TLibHandle values begins

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
    if SameText(Libs[I].Name, ExtractFileName(aName)) then
    begin
      Result := I;
      Exit;
    end;
end;

/// This method is assigned to each TmlBaseLoader and forwards the event to the global MlOnDependencyLoad procedure if one is assigned
procedure TMlLibraryManager.DoDependencyLoad(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
    aMemStream: TMemoryStream; var aFreeStream: Boolean);
begin
  if Assigned(fOnDependencyLoad) then
    fOnDependencyLoad(aLibName, aDependentLib, aLoadAction, aMemStream, aFreeStream);
end;

constructor TMlLibraryManager.Create;
begin
  inherited;
  fLibs := TList.Create;
  InitializeCriticalSection(fCrit);
end;

destructor TMlLibraryManager.Destroy;
begin
  while fLibs.Count > 0 do
    FreeLibraryMl(Libs[0].Handle);
  fLibs.Free;
  DeleteCriticalSection(fCrit);
  inherited;
end;

/// LoadLibraryMem: aName is compared to the loaded libraries and if found the
/// reference count is incremented. If the aName is empty or not found the library is loaded
function TMlLibraryManager.LoadLibraryMl(aSource: TMemoryStream; aLibFileName: String): TLibHandle;
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
        fLibs.Add(Loader); // It is added first to reserve the handle given
        Loader.OnDependencyLoad := DoDependencyLoad;
        Loader.Handle := GetNewHandle;
        Loader.RefCount := 1;
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

/// Decrement the RefCount of a library on each call and unload/free it if the count reaches 0
procedure TMlLibraryManager.FreeLibraryMl(aHandle: TLibHandle);
var
  Index: Integer;
  Lib: TMlBaseLoader;
begin
  EnterCriticalSection(fCrit);
  try
    Index := LibraryIndexByHandle(aHandle);
    if Index <> -1 then
    begin
      Lib := Libs[Index];
      Lib.RefCount := Lib.RefCount - 1;
      if Lib.RefCount = 0 then
      begin
        Lib.Free;
        fLibs.Remove(Lib);
      end;
    end
    else
      raise EMlInvalidHandle.Create('Invalid library handle');
  finally
    LeaveCriticalSection(fCrit);
  end;
end;

function TMlLibraryManager.GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].GetFunctionAddress(lpProcName)
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].FindResourceMl(lpName, lpType)
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].LoadResourceMl(hResInfo)
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].SizeOfResourceMl(hResInfo)
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.GetModuleFileNameMl(aHandle: TLibHandle): String;
var
  Index: Integer;
begin
  Index := LibraryIndexByHandle(aHandle);
  if Index <> -1 then
    Result := Libs[Index].Name
  else
    raise EMlInvalidHandle.Create('Invalid library handle');
end;

function TMlLibraryManager.GetModuleHandleMl(aModuleName: String): TLibHandle;
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
function TMlLibraryManager.LoadPackageMl(aSource: TMemoryStream; aLibFileName: String; aValidatePackage:
    TValidatePackageProc): TLibHandle;
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
        fLibs.Add(Loader); // It is added first to reserve the handle given
        Loader.OnDependencyLoad := DoDependencyLoad;
        Loader.Handle := GetNewHandle; // The handle must be assigned before LoadFromStream, because it is used in RegisterModule
        Loader.RefCount := 1;
        Loader.LoadFromStream(aSource, aLibFileName, aValidatePackage);
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

procedure TMlLibraryManager.UnloadPackageMl(aHandle: TLibHandle);
var
  Index: Integer;
  Lib: TBPLLoader;
begin
  EnterCriticalSection(fCrit);
  try
    Index := LibraryIndexByHandle(aHandle);
    if Index <> -1 then
    begin
      Lib := Libs[Index] as TBPLLoader;
      Lib.RefCount := Lib.RefCount - 1;
      if Lib.RefCount = 0 then
      begin
        Lib.Free;
        fLibs.Remove(Lib);
      end;
    end
    else
      raise EMlInvalidHandle.Create('Invalid library handle');
  finally
    LeaveCriticalSection(fCrit);
  end;
end;


{$IFDEF MLHOOKED}
{ ============ Hooked DLL Library memory functions ============ }
{ ============================================================= }

function LoadLibraryHooked(lpLibFileName: PChar): HMODULE; stdcall;
begin
  Result := Manager.LoadLibraryMl(lpLibFileName);
end;

function FreeLibraryHooked(hModule: HMODULE): BOOL; stdcall;
begin
  Manager.FreeLibraryMl(hModule);
  Result := true;
end;

function GetProcAddressHooked(hModule: HMODULE; lpProcName: LPCSTR): FARPROC; stdcall;
begin
  Result := Manager.GetProcAddressMl(hModule, lpProcName);
end;

function FindResourceHooked(hModule: HMODULE; lpName, lpType: PChar): HRSRC; stdcall;
begin
  Result := Manager.FindResourceMl(hModule, lpName, lpType);
end;

function LoadResourceHooked(hModule: HMODULE; hResInfo: HRSRC): HGLOBAL; stdcall;
begin
  Result := Manager.LoadResourceMl(hModule, hResInfo);
end;

function SizeofResourceHooked(hModule: HMODULE; hResInfo: HRSRC): DWORD; stdcall;
begin
  Result := Manager.SizeOfResourceMl(hModule, hResInfo);
end;

function GetModuleFileNameHooked(hModule: HINST; lpFilename: PChar; nSize: DWORD): DWORD; stdcall;
var
  S: String;
begin
  FillChar(lpFilename, Length(lpFilename) * SizeOf(lpFilename[0]), 0);
  S := Manager.GetModuleFileNameMl(hModule);
  StrLCopy(lpFilename, PChar(S), Length(lpFilename) - 1);
  if Length(S) > Length(lpFilename) - 1 then
    Result := Length(lpFilename)
  else
    Result := Length(S);
end;

function GetModuleHandleHooked(lpModuleName: PChar): HMODULE; stdcall;
begin
  Result := Manager.GetModuleHandleMl(lpModuleName);
end;

{ TMlHookedLibraryManager }

procedure TMlHookedLibraryManager.ReadLoadedLibs;
var
  TH32Handle: THandle;
  ModuleEntry: TModuleEntry32;
  HandleCount: Integer;
begin
  TH32Handle := CreateToolHelp32SnapShot(TH32CS_SNAPMODULE, 0);
  Win32Check(TH32Handle <> 0);
  try
    // Get the current process handle as a loaded module
    HandleCount := 1;
    SetLength(fWinHandles, 1);
    ModuleEntry.dwSize := SizeOf(ModuleEntry);
    Win32Check(Module32First(TH32Handle, ModuleEntry));
    fWinHandles[0] := ModuleEntry.hModule;
    // Get the rest of the loaded module handles
    while Module32Next(TH32Handle, ModuleEntry) do
    begin
      if HandleCount >= Length(fWinHandles) then
        SetLength(fWinHandles, Length(fWinHandles) + 100);
      fWinHandles[HandleCount] := ModuleEntry.hModule;
      Inc(HandleCount);
    end;
    SetLength(fWinHandles, HandleCount);
  finally
    CloseHandle(TH32Handle);
  end;
end;

procedure TMlHookedLibraryManager.HookAPIs;
var
  ModuleBase: Pointer;
begin
  ModuleBase := Pointer(GetModuleHandle(nil));
  fHooks.HookImport(ModuleBase, kernel32, 'LoadLibraryA',       Pointer(@LoadLibraryHooked),      Pointer(@fLoadLibraryOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'FreeLibrary',        Pointer(@FreeLibraryHooked),       Pointer(@fFreeLibraryOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'GetProcAddress',     Pointer(@GetProcAddressHooked),    Pointer(@fGetProcAddressOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'FindResourceA',      Pointer(@FindResourceHooked),      Pointer(@fFindResourceOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'LoadResource',       Pointer(@LoadResourceHooked),      Pointer(@fLoadResourceOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'SizeofResource',     Pointer(@SizeofResourceHooked),    Pointer(@fSizeofResourceOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'GetModuleFileNameA', Pointer(@GetModuleFileNameHooked), Pointer(@fGetModuleFileNameOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'GetModuleHandleA',   Pointer(@GetModuleHandleHooked),   Pointer(@fGetModuleHandleOrig));
end;

constructor TMlHookedLibraryManager.Create;
begin
  inherited;
  ReadLoadedLibs;
  fHooks := TJclPeMapImgHooks.Create;
  HookAPIs;
end;

destructor TMlHookedLibraryManager.Destroy;
begin
  fHooks.UnhookAll;
  fHooks.Free;
  inherited;
end;

function TMlHookedLibraryManager.LoadLibraryMl(lpLibFileName: PChar): TLibHandle;
begin
  // Just forward the call to the original API and check the result. In the future the handle returned can be checked for clashes
  Result := fLoadLibraryOrig(lpLibFileName);
  Win32Check(Result <> 0);
end;

function TMlHookedLibraryManager.LoadLibraryMl(aSource: TMemoryStream; aLibFileName: String): TLibHandle;
begin
  Result := inherited LoadLibraryMl(aSource, aLibFileName);
end;

procedure TMlHookedLibraryManager.FreeLibraryMl(aHandle: TLibHandle);
begin
  if IsWinHandle(aHandle) then
    Win32Check(fFreeLibraryOrig(aHandle))
  else
    inherited;
end;

function TMlHookedLibraryManager.GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC;
begin
  if IsWinHandle(aHandle) then
  begin
    Result := fGetProcAddressOrig(aHandle, lpProcName);
    Win32Check(Assigned(Result));
  end else
    Result := inherited GetProcAddressMl(aHandle, lpProcName);
end;

function TMlHookedLibraryManager.FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC;
begin
  if IsWinHandle(aHandle) then
  begin
    Result := fFindResourceOrig(aHandle, lpName, lpType);
    Win32Check(Result <> 0);
  end else
    Result := inherited FindResourceMl(aHandle, lpName, lpType);
end;

function TMlHookedLibraryManager.LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL;
begin
  if IsWinHandle(aHandle) then
  begin
    Result := fLoadResourceOrig(aHandle, hResInfo);
    Win32Check(Result <> 0);
  end else
    Result := inherited LoadResourceMl(aHandle, hResInfo);
end;

function TMlHookedLibraryManager.SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD;
begin
  if IsWinHandle(aHandle) then
  begin
    Result := fSizeofResourceOrig(aHandle, hResInfo);
    Win32Check(Result <> 0);
  end else
    Result := inherited SizeOfResourceMl(aHandle, hResInfo);
end;

function TMlHookedLibraryManager.GetModuleFileNameMl(aHandle: TLibHandle): String;
begin
  if IsWinHandle(aHandle) then
  begin
    SetLength(Result, MAX_PATH);
    Win32Check(fGetModuleFileNameOrig(aHandle, @Result[1], MAX_PATH) <> 0);
  end else
    Result := inherited GetModuleFileNameMl(aHandle);
end;

function TMlHookedLibraryManager.GetModuleHandleMl(aModuleName: String): TLibHandle;
begin
  Result := fGetModuleHandleOrig(PChar(aModuleName));
  if Result = 0 then
    Result := inherited GetModuleHandleMl(aModuleName);
end;

function TMlHookedLibraryManager.IsWinHandle(aHandle: TLibHandle): Boolean;
var
  ModName: array[0..0] of Char; // No need for a buffer for the full path, we just care if the handle is valid
begin
  Result := fGetModuleFileNameOrig(aHandle, ModName, Length(ModName)) <> 0;
end;

{$ENDIF MLHOOKED}

initialization
{$IFDEF MLHOOKED}
  Manager := TMlHookedLibraryManager.Create;
{$ELSE}
  Manager := TMlLibraryManager.Create;
{$ENDIF MLHOOKED}

finalization
  Manager.Free;

end.
