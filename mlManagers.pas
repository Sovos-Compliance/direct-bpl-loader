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

{$I mlDefines.inc}

unit mlManagers;

interface

uses
  SysUtils,
  Classes,
  SysConst,
  Windows,
  TlHelp32,
  HashTrie,
{$IFDEF MLHOOKED}
  mlKOLDetours,
{$ENDIF}  
  mlTypes,
  mlBaseLoader,
  mlBPLLoader;

type
  TMlLibraryManager = class
  private
    fCrit            : TRTLCriticalSection;
    fLibs            : TList;
    fHandleHash      : TIntegerHashTrie;
    fNamesHash       : TStringHashTrie;
    fOnDependencyLoad: TMlLoadDependentLibraryEvent;
    procedure DoDependencyLoad(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aStream:
        TStream; var aFreeStream: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    function GetGlobalModuleHandle(const aModuleName: String): TLibHandle;
    function IsWinLoaded(aHandle: TLibHandle): Boolean; virtual;
    function IsMemLoaded(aHandle: TLibHandle): Boolean;
    function LoadLibraryMl(aStream: TStream; const aLibFileName: String): TLibHandle; virtual;
    function FreeLibraryMl(aHandle: TLibHandle): Boolean; virtual;
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
    procedure UnhookAPIs;
    function IsWinLoaded(aHandle: TLibHandle): Boolean; override;
    function LoadLibraryMl(lpLibFileName: PChar): TLibHandle; reintroduce; overload;
    function LoadLibraryMl(aStream: TStream; const aLibFileName: String): TLibHandle; overload; override;
    function FreeLibraryMl(aHandle: TLibHandle): Boolean; override;
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
  fHandleHash := TIntegerHashTrie.Create;
  fNamesHash := TStringHashTrie.Create;
  fNamesHash.CaseSensitive := false;
end;

destructor TMlLibraryManager.Destroy;
var
  Counter: Integer;
begin
  //VG 131214: This should only be called at the program termination. If the usage is proper, all the libs should
  // have been freed by the user. In case any are left, try to free them forcefully, which could raise exceptions
  // Try to free them as gracefully as possible, without knowing which one requires which, so unload them one at a time
  // from the begining of the list to the end, and then repeat till no libraries remain
  while fLibs.Count > 0 do
  begin
    Counter := 0;
    while Counter < fLibs.Count do
    begin
      try
        FreeLibraryMl(TMlBaseLoader(fLibs[Counter]).Handle);
      except
        // Exceptions could be logged if there is some logging library
      end;
      Inc(Counter);
    end;
  end;

  fLibs.Free;
  DeleteCriticalSection(fCrit);
  fHandleHash.Free;
  fNamesHash.Free;
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

function TMlLibraryManager.IsMemLoaded(aHandle: TLibHandle): Boolean;
begin
  Result := fHandleHash.Find(aHandle);
end;

/// LoadLibraryMem: aName is compared to the loaded libraries and if found the
/// reference count is incremented. If the aName is empty or not found the library is loaded
function TMlLibraryManager.LoadLibraryMl(aStream: TStream; const aLibFileName: String): TLibHandle;
var
  Loader: TMlBaseLoader;
begin
  Result := 0;
  EnterCriticalSection(fCrit);
  try
    if fNamesHash.Find(aLibFileName, TObject(Loader)) then
    begin
      // Increase the RefCount of the already loaded library
      Loader.RefCount := Loader.RefCount + 1;
      Result := Loader.Handle;
    end else
    begin
      // Or load the library if it is a new one
      Loader := TMlBaseLoader.Create;
      try
        fLibs.Add(Loader); // It is added to the list first because loading checks its own handle (in LoadPackageMl)
        Loader.OnDependencyLoad := DoDependencyLoad;
        Loader.LoadFromStream(aStream, aLibFileName);
        fHandleHash.Add(Loader.Handle, TObject(Loader));
        fNamesHash.Add(aLibFileName, TObject(Loader));
        Result := Loader.Handle;
      except on E: Exception do
        begin
          fLibs.Remove(Loader);
          Loader.Free;
          ReportError(EMlLibraryLoadError, E.Message, GetLastError);
        end;
      end;
    end;
  finally
    LeaveCriticalSection(fCrit);
  end;
end;

/// Decrement the RefCount of a library on each call and unload/free it if the count reaches 0
function TMlLibraryManager.FreeLibraryMl(aHandle: TLibHandle): Boolean;
var
  Lib: TMlBaseLoader;
begin
  EnterCriticalSection(fCrit);
  try
    Result := false;
    if fHandleHash.Find(aHandle, TObject(Lib)) then
    begin
      Lib.RefCount := Lib.RefCount - 1;
      if Lib.RefCount = 0 then
      begin
        fLibs.Remove(Lib);
        fHandleHash.Delete(Lib.Handle);
        fNamesHash.Delete(Lib.Name);
        Lib.Free;
      end;
      Result := true;
    end
    else
      ReportError(EOSError, 'Invalid library handle', ERROR_INVALID_HANDLE);
  finally
    LeaveCriticalSection(fCrit);
  end;
end;

function TMlLibraryManager.GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC;
var
  Lib: TMlBaseLoader;
begin
  Result := nil;
  if fHandleHash.Find(aHandle, TObject(Lib)) then
    Result := Lib.GetFunctionAddress(lpProcName)
  else
    ReportError(EOSError, 'Invalid library handle', ERROR_INVALID_HANDLE);
end;

function TMlLibraryManager.FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC;
var
  Lib: TMlBaseLoader;
begin
  Result := 0;
  if fHandleHash.Find(aHandle, TObject(Lib)) then
    Result := Lib.FindResourceMl(lpName, lpType)
  else
    ReportError(EOSError, 'Invalid library handle', ERROR_INVALID_HANDLE);
end;

function TMlLibraryManager.LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL;
var
  Lib: TMlBaseLoader;
begin
  Result := 0;
  if fHandleHash.Find(aHandle, TObject(Lib)) then
    Result := Lib.LoadResourceMl(hResInfo)
  else
    ReportError(EOSError, 'Invalid library handle', ERROR_INVALID_HANDLE);
end;

function TMlLibraryManager.SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD;
var
  Lib: TMlBaseLoader;
begin
  Result := 0;
  if fHandleHash.Find(aHandle, TObject(Lib)) then
    Result := Lib.SizeOfResourceMl(hResInfo)
  else
    ReportError(EOSError, 'Invalid library handle', ERROR_INVALID_HANDLE);
end;

function TMlLibraryManager.GetModuleFileNameMl(aHandle: TLibHandle): String;
var
  Lib: TMlBaseLoader;
begin
  if fHandleHash.Find(aHandle, TObject(Lib)) then
    Result := Lib.Name
  else
  begin
    // Raising an exception here breaks hooked LoadLibrary, so don't use ReportError for the moment
    Result := '';
    SetLastError(ERROR_INVALID_HANDLE);
  end;
end;

function TMlLibraryManager.GetModuleHandleMl(const aModuleName: String): TLibHandle;
var
  Lib: TMlBaseLoader;
begin
  if fNamesHash.Find(aModuleName, TObject(Lib)) then
    Result := Lib.Handle
  else
  begin
    // Raising an exception here breaks hooked LoadPackage, so don't use ReportError for the moment
    Result := 0;
    SetLastError(ERROR_INVALID_NAME);
  end;
end;

/// Function to emulate the LoadPackage from a stream
/// Source is taken from the original Delphi RTL functions LoadPackage, InitializePackage in SysUtils
function TMlLibraryManager.LoadPackageMl(aStream: TStream; const aLibFileName: String; aValidatePackage:
    TValidatePackageProc): TLibHandle;
var
  Loader: TBPLLoader;
begin
  Result := 0;
  EnterCriticalSection(fCrit);
  try
    if fNamesHash.Find(aLibFileName, TObject(Loader)) then
    begin
      // Increase the RefCount of the already loaded library
      Loader.RefCount := Loader.RefCount + 1;
      Result := Loader.Handle;
    end else
    begin
      // Or load the library if it is a new one
      Loader := TBPLLoader.Create;
      try
        fLibs.Add(Loader); // It is added to the list first because loading checks its own handle (in LoadPackageMl)
        Loader.OnDependencyLoad := DoDependencyLoad;
        Loader.LoadFromStream(aStream, aLibFileName, aValidatePackage);
        fHandleHash.Add(Loader.Handle, TObject(Loader));
        fNamesHash.Add(aLibFileName, TObject(Loader));
        Result := Loader.Handle;
      except on E: Exception do
        begin
          fLibs.Remove(Loader);
          Loader.Free;
          ReportError(EPackageError, E.Message, GetLastError);
        end;
      end;
    end;
  finally
    LeaveCriticalSection(fCrit);
  end;
end;

procedure TMlLibraryManager.UnloadPackageMl(aHandle: TLibHandle);
var
  Lib: TBPLLoader;
begin
  EnterCriticalSection(fCrit);
  try
    if fHandleHash.Find(aHandle, TObject(Lib)) then
    begin
      Lib.RefCount := Lib.RefCount - 1;
      if Lib.RefCount = 0 then
      begin
        fLibs.Remove(Lib);
        fHandleHash.Delete(Lib.Handle);
        fNamesHash.Delete(Lib.Name);
        Lib.Free;
      end;
    end
    else
      ReportError(EPackageError, SInvalidPackageHandle, ERROR_INVALID_HANDLE);
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
  Result := Manager.FreeLibraryMl(hModule);
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
  Result := 0;
  S := Manager.GetModuleFileNameMl(hModule);
  if S <> '' then
  begin
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
begin
  @fLoadLibraryOrig       := InterceptCreate(@LoadLibrary, @LoadLibraryHooked);
  @fFreeLibraryOrig       := InterceptCreate(@FreeLibrary, @FreeLibraryHooked);
  @fFindResourceOrig      := InterceptCreate(@FindResource, @FindResourceHooked);
  @fLoadResourceOrig      := InterceptCreate(@LoadResource, @LoadResourceHooked);
  @fSizeofResourceOrig    := InterceptCreate(@SizeofResource, @SizeofResourceHooked);
  @fGetModuleFileNameOrig := InterceptCreate(@GetModuleFileName, @GetModuleFileNameHooked);
  @fGetModuleHandleOrig   := InterceptCreate(@GetModuleHandle, @GetModuleHandleHooked);
  @fGetProcAddressOrig    := InterceptCreate(@GetProcAddress, @GetProcAddressHooked);
  @fLoadPackageOrig       := InterceptCreate(@LoadPackage, @LoadPackageHooked);
  @fUnloadPackageOrig     := InterceptCreate(@UnloadPackage, @UnloadPackageHooked);
end;

procedure TMlHookedLibraryManager.UnhookAPIs;
begin
  InterceptRemove(@fLoadLibraryOrig, @LoadLibraryHooked);
  InterceptRemove(@fFreeLibraryOrig, @FreeLibraryHooked);
  InterceptRemove(@fFindResourceOrig, @FindResourceHooked);
  InterceptRemove(@fLoadResourceOrig, @LoadResourceHooked);
  InterceptRemove(@fSizeofResourceOrig, @SizeofResourceHooked);
  InterceptRemove(@fGetModuleFileNameOrig, @GetModuleFileNameHooked);
  InterceptRemove(@fGetModuleHandleOrig, @GetModuleHandleHooked);
  InterceptRemove(@fGetProcAddressOrig, @GetProcAddressHooked);
  InterceptRemove(@fLoadPackageOrig, @LoadPackageHooked);
  InterceptRemove(@fUnloadPackageOrig, @UnloadPackageHooked);
end;

constructor TMlHookedLibraryManager.Create;
begin
  inherited;
  // The HookAPIs call moved out of the constructor and has to be called manually immediately after the constructor
  // Otherwise there is a high chance that another thread calls one of the hooked APIs and tries to forward it to the
  // Manager object while its constructor is not complete yet, the Manager object is still nil, which leads to AVs
  //  HookAPIs;  // Has to be called manually after the TMlHookedLibraryManager.Create call
end;

destructor TMlHookedLibraryManager.Destroy;
begin
  inherited;
  UnhookAPIs; // Unhook the APIs last because they could be used in the inherited destructor when freeing libraries
end;

function TMlHookedLibraryManager.IsWinLoaded(aHandle: TLibHandle): Boolean;
var
  ModName: array[0..0] of Char; // No need for a buffer for the full path, we just care if the handle is valid
begin
  // Check if the GetModuleFileName is hooked because might be called in the destructor while freeing the libs
  // and the APIs are already unhooked
  if Assigned(fGetModuleFileNameOrig) then
    Result := fGetModuleFileNameOrig(aHandle, ModName, Length(ModName)) <> 0
  else
    Result := GetModuleFileName(aHandle, ModName, Length(ModName)) <> 0;
end;

function TMlHookedLibraryManager.LoadLibraryMl(lpLibFileName: PChar): TLibHandle;
begin
  // Just forward the call to the original API and check the result
  Result := fLoadLibraryOrig(lpLibFileName);
  if Result = 0 then
    ReportError(EOSError, SysErrorMessage(GetLastError), GetLastError);
end;

function TMlHookedLibraryManager.LoadLibraryMl(aStream: TStream; const aLibFileName: String): TLibHandle;
begin
  Result := inherited LoadLibraryMl(aStream, aLibFileName);
end;

function TMlHookedLibraryManager.FreeLibraryMl(aHandle: TLibHandle): Boolean;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fFreeLibraryOrig(aHandle);
    if not Result then
      ReportError(EOSError, SysErrorMessage(GetLastError), GetLastError);
  end else
    Result := inherited FreeLibraryMl(aHandle);
end;

function TMlHookedLibraryManager.GetProcAddressMl(aHandle: TLibHandle; lpProcName: LPCSTR): FARPROC;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fGetProcAddressOrig(aHandle, lpProcName);
    if not Assigned(Result) then
      ReportError(EOSError, SysErrorMessage(GetLastError), GetLastError);
  end else
    Result := inherited GetProcAddressMl(aHandle, lpProcName);
end;

function TMlHookedLibraryManager.FindResourceMl(aHandle: TLibHandle; lpName, lpType: PChar): HRSRC;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fFindResourceOrig(aHandle, lpName, lpType);
    if Result = 0 then
      ReportError(EOSError, SysErrorMessage(GetLastError), GetLastError);
  end else
    Result := inherited FindResourceMl(aHandle, lpName, lpType);
end;

function TMlHookedLibraryManager.LoadResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): HGLOBAL;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fLoadResourceOrig(aHandle, hResInfo);
    if Result = 0 then
      ReportError(EOSError, SysErrorMessage(GetLastError), GetLastError);
  end else
    Result := inherited LoadResourceMl(aHandle, hResInfo);
end;

function TMlHookedLibraryManager.SizeOfResourceMl(aHandle: TLibHandle; hResInfo: HRSRC): DWORD;
begin
  if IsWinLoaded(aHandle) then
  begin
    Result := fSizeofResourceOrig(aHandle, hResInfo);
    if Result = 0 then
      ReportError(EOSError, SysErrorMessage(GetLastError), GetLastError);
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
