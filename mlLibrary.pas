{*******************************************************************************
*  Created by Vladimir Georgiev, 2014                                          *
*                                                                              *
*  Description:                                                                *
*  Unit providing several methods to load and use a DLL/BPL library from       *
*  memory instead of a file. The methods are named after the original WinAPIs  *
*  like LoadLibrary, FreeLibrary, GetProcAddress, etc, but with a Mem suffix   *
*  for the Unhooked version and without a suffix for the Hooked version.       *
*  Same for LoadPackage and UnloadPackage for working with BPLs                *
*  The underlying functionality is provided by the TMl(Hooked)LibraryManager   *
*  class that manages the loading, unloading, reference counting, generation of*
*  handles, etc. It uses the TMlBaseLoader for the loading/unloading of libs.  *
*                                                                              *
*******************************************************************************}

{$I APIMODE.INC}
{$I DelphiVersion_defines.inc}

unit mlLibrary;

interface

uses
  SysUtils,
  Classes,
  SysConst,
  Windows,
  mlTypes,
  mlManagers;


{$IFDEF MLHOOKED}
// DLL loading functions. They only forward the calls to the TMlLibraryManager instance
function LoadLibrary(aStream: TStream; lpLibFileName: PChar): HMODULE; overload;
function LoadLibrary(aStream: TStream; const aLibFileName: String): HMODULE; overload;
function LoadLibrary(lpLibFileName: PChar): HMODULE; overload;

/// BPL loading functions
function LoadPackage(aStream: TStream; const aLibFileName: String {$IFDEF DELPHI2007}; aValidatePackage:
    TValidatePackageProc = nil{$ENDIF}): TLibHandle; overload;
function LoadPackage(const aLibFileName: String {$IFDEF DELPHI2007}; aValidatePackage:
    TValidatePackageProc = nil{$ENDIF}): TLibHandle; overload;

{$ELSE}
// DLL loading functions. They only forward the calls to the TMlLibraryManager instance
function LoadLibraryMem(aStream: TStream; const aLibFileName: String): TLibHandle;
procedure FreeLibraryMem(hModule: TLibHandle);
function GetProcAddressMem(hModule: TLibHandle; lpProcName: LPCSTR): FARPROC;
function FindResourceMem(hModule: TLibHandle; lpName, lpType: PChar): HRSRC;
function LoadResourceMem(hModule: TLibHandle; hResInfo: HRSRC): HGLOBAL;
function SizeOfResourceMem(hModule: TLibHandle; hResInfo: HRSRC): DWORD;
function GetModuleFileNameMem(hModule: TLibHandle): String;
function GetModuleHandleMem(const ModuleName: String): TLibHandle;

/// BPL loading functions
function LoadPackageMem(aStream: TStream; const aLibFileName: String {$IFDEF DELPHI2007}; aValidatePackage:
    TValidatePackageProc = nil{$ENDIF}): TLibHandle; overload;
procedure UnloadPackageMem(Module: TLibHandle);
{$ENDIF MLHOOKED}

/// Helper functions to check module load status and set a callback function
function MlGetGlobalModuleHandle(const aLibFileName: String): TLibHandle;
function MlIsWinLoaded(hModule: TLibHandle): Boolean;
function MlIsMemLoaded(hModule: TLibHandle): Boolean;
procedure MlSetOnLoadCallback(aCallbackProc: TMlLoadDependentLibraryEvent);

//TODO VG 090714: This method is used only to reset the loader during unit testing. Can be removed
{$IFDEF _CONSOLE_TESTRUNNER}
procedure UnloadAllLibraries;
{$ENDIF _CONSOLE_TESTRUNNER}

implementation

{$IFDEF MLHOOKED}
{ ============ Hooked DLL Library memory functions ============ }
{ ============================================================= }

function LoadLibrary(aStream: TStream; lpLibFileName: PChar): HMODULE;
begin
  Result := Manager.LoadLibraryMl(aStream, lpLibFileName);
end;

function LoadLibrary(aStream: TStream; const aLibFileName: String): HMODULE;
begin
  Result := Manager.LoadLibraryMl(aStream, aLibFileName);
end;

function LoadLibrary(lpLibFileName: PChar): HMODULE;
begin
  Result := Manager.LoadLibraryMl(lpLibFileName);
end;

{ ============ Hooked BPL Library memory functions ============ }
{ ============================================================= }

function LoadPackage(aStream: TStream; const aLibFileName: String {$IFDEF DELPHI2007}; aValidatePackage:
    TValidatePackageProc = nil{$ENDIF}): TLibHandle;
begin
  Result := Manager.LoadPackageMl(aStream, aLibFileName, {$IFDEF DELPHI2007} aValidatePackage {$ELSE} nil {$ENDIF});
end;

function LoadPackage(const aLibFileName: String {$IFDEF DELPHI2007}; aValidatePackage:
    TValidatePackageProc = nil{$ENDIF}): TLibHandle;
begin
  Result := Manager.LoadPackageMl(aLibFileName, {$IFDEF DELPHI2007} aValidatePackage {$ELSE} nil {$ENDIF});
end;


{$ELSE}
{ ============ Unhooked DLL Library memory functions ============ }
{ =============================================================== }

function LoadLibraryMem(aStream: TStream; const aLibFileName: String): TLibHandle;
begin
  Result := Manager.LoadLibraryMl(aStream, aLibFileName);
end;

procedure FreeLibraryMem(hModule: TLibHandle);
begin
  Manager.FreeLibraryMl(hModule);
end;

function GetProcAddressMem(hModule: TLibHandle; lpProcName: LPCSTR): FARPROC;
begin
  Result := Manager.GetProcAddressMl(hModule, lpProcName);
end;

function FindResourceMem(hModule: TLibHandle; lpName, lpType: PChar): HRSRC;
begin
  Result := Manager.FindResourceMl(hModule, lpName, lpType);
end;

function LoadResourceMem(hModule: TLibHandle; hResInfo: HRSRC): HGLOBAL;
begin
  Result := Manager.LoadResourceMl(hModule, hResInfo);
end;

function SizeOfResourceMem(hModule: TLibHandle; hResInfo: HRSRC): DWORD;
begin
  Result := Manager.SizeOfResourceMl(hModule, hResInfo);
end;

function GetModuleFileNameMem(hModule: TLibHandle): String;
begin
  Result := Manager.GetModuleFileNameMl(hModule);
end;

function GetModuleHandleMem(const ModuleName: String): TLibHandle;
begin
  Result := Manager.GetModuleHandleMl(ModuleName);
end;


{ ============ BPL Library memory functions ============ }
{ ====================================================== }

function LoadPackageMem(aStream: TStream; const aLibFileName: String {$IFDEF DELPHI2007}; aValidatePackage:
    TValidatePackageProc = nil{$ENDIF}): TLibHandle;
begin
  Result := Manager.LoadPackageMl(aStream, aLibFileName, {$IFDEF DELPHI2007} aValidatePackage {$ELSE} nil {$ENDIF});
end;

procedure UnloadPackageMem(Module: TLibHandle);
begin
  Manager.UnloadPackageMl(Module);
end;
{$ENDIF MLHOOKED}

function MlGetGlobalModuleHandle(const aLibFileName: String): TLibHandle;
begin
  Result := Manager.GetGlobalModuleHandle(aLibFileName);
end;

function MlIsWinLoaded(hModule: TLibHandle): Boolean;
begin
  Result := Manager.IsWinLoaded(hModule);
end;

function MlIsMemLoaded(hModule: TLibHandle): Boolean;
begin
  Result := Manager.IsMemLoaded(hModule);
end;

procedure MlSetOnLoadCallback(aCallbackProc: TMlLoadDependentLibraryEvent);
begin
  Manager.OnDependencyLoad := aCallbackProc;
end;

//TODO VG 090714: This method is used only to reset the manager during unit testing. Can be removed
{$IFDEF _CONSOLE_TESTRUNNER}
procedure UnloadAllLibraries;
begin
  Manager.Free;
{$IFDEF MLHOOKED}
  Manager := TMlHookedLibraryManager.Create;
  Manager.HookAPIs;
{$ELSE}
  Manager := TMlLibraryManager.Create;
{$ENDIF}
end;
{$ENDIF _CONSOLE_TESTRUNNER}

end.
