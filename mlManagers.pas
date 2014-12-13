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
    function LibraryIndexByHandle(aHandle: TLibHandle): Integer;
    function LibraryIndexByName(const aLibName: String): Integer;
    procedure DoDependencyLoad(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aStream:
        TStream; var aFreeStream: Boolean);
    property Libs[aIndex: Integer]: TMlBaseLoader read GetLibs;
  public
    constructor Create;
    destructor Destroy; override;
    function GetGlobalModuleHandle(const aModuleName: String): TLibHandle;
    function IsWinLoaded(aHandle: TLibHandle): Boolean; virtual;
    function LoadLibraryMl(aStream: TStream; const aLibFileName: String): TLibHandle; virtual;
    procedure FreeLibraryMl(aHandle: TLibHandle); virtual;
    function GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC; virtual;
    function FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC; virtual;
    function LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL; virtual;
    function SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD; virtual;
    function GetModuleFileNameMl(aHandle: TLibHandle): String; virtual;
    function GetModuleHandleMl(const aModuleName: String): TLibHandle; virtual;

    function LoadPackageMl(aStream: TStream; const aLibFileName: String; aValidatePackage: TValidatePackageProc):
        TLibHandle; virtual;
    procedure UnloadPackageMl(aHandle: TLibHandle); virtual;
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
    fLoadPackageOrig      : TLoadPackageFunc;
    fUnloadPackageOrig    : TUnloadPackageProc;

  public
    constructor Create;
    destructor Destroy; override;
    procedure HookAPIs;
    function IsWinLoaded(aHandle: TLibHandle): Boolean; override;
    function LoadLibraryMl(lpLibFileName: PChar): TLibHandle; reintroduce; overload;
    function LoadLibraryMl(aStream: TStream; const aLibFileName: String): TLibHandle; overload; override;
    procedure FreeLibraryMl(aHandle: TLibHandle); override;
    function GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC; override;
    function FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC; override;
    function LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL; override;
    function SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD; override;
    function GetModuleFileNameMl(aHandle: TLibHandle): String; override;
    function GetModuleHandleMl(const aModuleName: String): TLibHandle; override;
    function LoadPackageMl(const aLibFileName: String; aValidatePackage: TValidatePackageProc): TLibHandle; reintroduce;
        overload;
    function LoadPackageMl(aStream: TStream; const aLibFileName: String; aValidatePackage: TValidatePackageProc):
        TLibHandle; overload; override;
    procedure UnloadPackageMl(aHandle: TLibHandle); override;
  end;
{$ENDIF MLHOOKED}

var
{$IFDEF MLHOOKED}
  Manager: TMlHookedLibraryManager;
{$ELSE}
  Manager: TMlLibraryManager;
{$ENDIF MLHOOKED}

implementation

{ TMlLibraryManager }

function TMlLibraryManager.GetLibs(aIndex: Integer): TMlBaseLoader;
begin
  if (aIndex < 0) or (aIndex >= fLibs.Count) then
    raise Exception.Create('Library index out of bounds');
  Result := fLibs[aIndex];
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
function TMlLibraryManager.LibraryIndexByName(const aLibName: String): Integer;
var
  I: Integer;
begin
  Result := -1;
  if aLibName = '' then
    Exit;
  for I := 0 to fLibs.Count - 1 do
    if SameText(Libs[I].Name, ExtractFileName(aLibName)) then
    begin
      Result := I;
      Exit;
    end;
end;

/// This method is assigned to each TmlBaseLoader and forwards the event to the global MlOnDependencyLoad procedure if one is assigned
procedure TMlLibraryManager.DoDependencyLoad(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
    aStream: TStream; var aFreeStream: Boolean);
begin
  if Assigned(fOnDependencyLoad) then
    fOnDependencyLoad(aLibName, aDependentLib, aLoadAction, aStream, aFreeStream);
end;

constructor TMlLibraryManager.Create;
begin
  inherited;
  fLibs := TList.Create;
  InitializeCriticalSection(fCrit);
end;

destructor TMlLibraryManager.Destroy;
var
  Counter: Integer;
begin
  //VG 131214: This should only be called at the program termination. If the usage is proper, all the libs should
  // have been freed by the user. In case any are left, try to free them forcefully, which could raise exceptions
  // Try to free them as gracefully as possible, without knowing which one requires which, so unload them one at a time
  // from the begining of the list to the end, and then repeat
  while fLibs.Count > 0 do
  begin
    Counter := 0;
    while Counter < fLibs.Count do
    begin
      try
        FreeLibraryMl(Libs[Counter].Handle);
      except
        // Exceptions could be logged if there is some logging library
      end;
      Inc(Counter);
    end;
  end;

  fLibs.Free;
  DeleteCriticalSection(fCrit);
  inherited;
end;

/// Return the handle of a loaded module, regardless if it is from Mem or Disk
function TMlLibraryManager.GetGlobalModuleHandle(const aModuleName: String): TLibHandle;
begin
  Result := GetModuleHandle(PChar(aModuleName));
  if Result = 0 then
    Result := GetModuleHandleMl(aModuleName);
end;

function TMlLibraryManager.IsWinLoaded(aHandle: TLibHandle): Boolean;
var
  ModName: array[0..0] of Char; // No need for a buffer for the full path, we just care if the handle is valid
begin
  Result := GetModuleFileName(aHandle, ModName, Length(ModName)) <> 0;
end;

/// LoadLibraryMem: aName is compared to the loaded libraries and if found the
/// reference count is incremented. If the aName is empty or not found the library is loaded
function TMlLibraryManager.LoadLibraryMl(aStream: TStream; const aLibFileName: String): TLibHandle;
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
        fLibs.Add(Loader); // It is added to the list first because loading checks its own handle (in LoadPackageMl)
        Loader.OnDependencyLoad := DoDependencyLoad;
        Loader.LoadFromStream(aStream, aLibFileName);
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
        fLibs.Remove(Lib);
        Lib.Free;
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

function TMlLibraryManager.GetModuleHandleMl(const aModuleName: String): TLibHandle;
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
function TMlLibraryManager.LoadPackageMl(aStream: TStream; const aLibFileName: String; aValidatePackage:
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
        fLibs.Add(Loader); // It is added to the list first because loading checks its own handle (in LoadPackageMl)
        Loader.OnDependencyLoad := DoDependencyLoad;
        Loader.LoadFromStream(aStream, aLibFileName, aValidatePackage);
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
        fLibs.Remove(Lib);
        Lib.Free;
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
  S := Manager.GetModuleFileNameMl(hModule);
  StrLCopy(lpFilename, PChar(S), nSize);
  // Mimic the behaviour of the original GetModuleFileName API with settings the result and error code
  // VG 251114: Can be replaced with an exception if needed
  if Cardinal(Length(S)) > nSize then
  begin
    Result := nSize + 1;
    SetLastError(ERROR_INSUFFICIENT_BUFFER);
  end else
    Result := Length(S);
end;

function GetModuleHandleHooked(lpModuleName: PChar): HMODULE; stdcall;
begin
  Result := Manager.GetModuleHandleMl(lpModuleName);
end;

function LoadPackageHooked(const Name: string; AValidatePackage: TValidatePackageProc): HMODULE;
begin
  Result := Manager.LoadPackageMl(Name, AValidatePackage);
end;

procedure UnloadPackageHooked(Module: HMODULE);
begin
  Manager.UnloadPackageMl(Module);
end;

procedure TMlHookedLibraryManager.HookAPIs;
const
{$IFDEF VER130}
  RTL_NAME = 'vcl50.bpl';
{$ENDIF}
{$IFDEF VER185}
  RTL_NAME = 'rtl100.bpl';
{$ENDIF}
  LOAD_NAME   = '@Sysutils@LoadPackage$qqrx17System@AnsiString';
  UNLOAD_NAME = '@Sysutils@UnloadPackage$qqrui';
var
  ModuleBase: Pointer;
begin
  ModuleBase := Pointer(GetModuleHandle(nil));
  fHooks.HookImport(ModuleBase, kernel32, 'LoadLibraryA',       Pointer(@LoadLibraryHooked),       Pointer(@fLoadLibraryOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'FreeLibrary',        Pointer(@FreeLibraryHooked),       Pointer(@fFreeLibraryOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'FindResourceA',      Pointer(@FindResourceHooked),      Pointer(@fFindResourceOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'LoadResource',       Pointer(@LoadResourceHooked),      Pointer(@fLoadResourceOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'SizeofResource',     Pointer(@SizeofResourceHooked),    Pointer(@fSizeofResourceOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'GetModuleFileNameA', Pointer(@GetModuleFileNameHooked), Pointer(@fGetModuleFileNameOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'GetModuleHandleA',   Pointer(@GetModuleHandleHooked),   Pointer(@fGetModuleHandleOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'GetProcAddress',     Pointer(@GetProcAddressHooked),    Pointer(@fGetProcAddressOrig));
  fHooks.HookImport(ModuleBase, kernel32, 'GetProcAddress',     Pointer(@GetProcAddressHooked),    Pointer(@fGetProcAddressOrig));
  fHooks.HookImport(ModuleBase, RTL_NAME, LOAD_NAME,            Pointer(@LoadPackageHooked),       Pointer(@fLoadPackageOrig));
  fHooks.HookImport(ModuleBase, RTL_NAME, UNLOAD_NAME,          Pointer(@UnloadPackageHooked),     Pointer(@fUnloadPackageOrig));
end;

constructor TMlHookedLibraryManager.Create;
begin
  inherited;
  fHooks := TJclPeMapImgHooks.Create;
  // The HookAPIs call moved out of the constructor and has to be called manually
  // Otherwise there is a chance of conflicts that the JCL HookImport function tries to use GetProcAddress, GetModuleHandle
  // that are already hooked and forwarded to the Manager. However, the constructor of the Manager is not complete yet
  // and the Manager object is still nil, which in turn leads to AVs
  //  HookAPIs;  // Has to be called manually after the TMlHookedLibraryManager.Create call
end;

destructor TMlHookedLibraryManager.Destroy;
begin
  fHooks.UnhookAll;
  fHooks.Free;
  inherited;
end;

function TMlHookedLibraryManager.IsWinLoaded(aHandle: TLibHandle): Boolean;
var
  ModName: array[0..0] of Char; // No need for a buffer for the full path, we just care if the handle is valid
begin
  Result := fGetModuleFileNameOrig(aHandle, ModName, Length(ModName)) <> 0;
end;

function TMlHookedLibraryManager.LoadLibraryMl(lpLibFileName: PChar): TLibHandle;
begin
  // Just forward the call to the original API and check the result. In the future the handle returned can be checked for clashes
  Result := fLoadLibraryOrig(lpLibFileName);
  Win32Check(Result <> 0);
end;

function TMlHookedLibraryManager.LoadLibraryMl(aStream: TStream; const aLibFileName: String): TLibHandle;
begin
  Result := inherited LoadLibraryMl(aStream, aLibFileName);
end;

procedure TMlHookedLibraryManager.FreeLibraryMl(aHandle: TLibHandle);
begin
  if IsWinLoaded(aHandle) then
    Win32Check(fFreeLibraryOrig(aHandle))
  else
    inherited;
end;

function TMlHookedLibraryManager.GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fGetProcAddressOrig(aHandle, lpProcName);
    Win32Check(Assigned(Result));
  end else
    Result := inherited GetProcAddressMl(aHandle, lpProcName);
end;

function TMlHookedLibraryManager.FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fFindResourceOrig(aHandle, lpName, lpType);
    Win32Check(Result <> 0);
  end else
    Result := inherited FindResourceMl(aHandle, lpName, lpType);
end;

function TMlHookedLibraryManager.LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fLoadResourceOrig(aHandle, hResInfo);
    Win32Check(Result <> 0);
  end else
    Result := inherited LoadResourceMl(aHandle, hResInfo);
end;

function TMlHookedLibraryManager.SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fSizeofResourceOrig(aHandle, hResInfo);
    Win32Check(Result <> 0);
  end else
    Result := inherited SizeOfResourceMl(aHandle, hResInfo);
end;

function TMlHookedLibraryManager.GetModuleFileNameMl(aHandle: TLibHandle): String;
var
  NameLen: Integer;
begin
  if IsWinLoaded(aHandle) then
  begin
    SetLength(Result, MAX_PATH + 1);
    NameLen := fGetModuleFileNameOrig(aHandle, @Result[1], MAX_PATH);
    Win32Check(NameLen <> 0);
    SetLength(Result, NameLen);
  end else
    Result := inherited GetModuleFileNameMl(aHandle);
end;

function TMlHookedLibraryManager.GetModuleHandleMl(const aModuleName: String): TLibHandle;
begin
  Result := fGetModuleHandleOrig(PChar(aModuleName));
  if Result = 0 then
    Result := inherited GetModuleHandleMl(aModuleName);
end;

function TMlHookedLibraryManager.LoadPackageMl(const aLibFileName: String; aValidatePackage: TValidatePackageProc):
    TLibHandle;
begin
  Result := fLoadPackageOrig(aLibFileName, aValidatePackage);
end;

function TMlHookedLibraryManager.LoadPackageMl(aStream: TStream; const aLibFileName: String; aValidatePackage:
    TValidatePackageProc): TLibHandle;
begin
  Result := inherited LoadPackageMl(aStream, aLibFileName, aValidatePackage);
end;

procedure TMlHookedLibraryManager.UnloadPackageMl(aHandle: TLibHandle);
begin
  if IsWinLoaded(aHandle) then
    fUnloadPackageOrig(aHandle)
  else
    inherited;
end;

{$ENDIF MLHOOKED}

initialization
{$IFDEF MLHOOKED}
  Manager := TMlHookedLibraryManager.Create;
  Manager.HookAPIs;
{$ELSE}
  Manager := TMlLibraryManager.Create;
{$ENDIF MLHOOKED}

finalization
  Manager.Free;

end.
