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
function LoadLibrary(aSource: TMemoryStream; lpLibFileName: PChar = nil): HMODULE; overload; stdcall;
function LoadLibrary(lpLibFileName: PChar): HMODULE; stdcall; overload;
function FreeLibrary(hModule: HMODULE): BOOL; stdcall;
function GetProcAddress(hModule: HMODULE; lpProcName: LPCSTR): FARPROC; stdcall;
function FindResource(hModule: HMODULE; lpName, lpType: PChar): HRSRC; stdcall;
function LoadResource(hModule: HMODULE; hResInfo: HRSRC): HGLOBAL; stdcall;
function SizeofResource(hModule: HMODULE; hResInfo: HRSRC): DWORD; stdcall;
function GetModuleFileName(hModule: HINST; lpFilename: PChar; nSize: DWORD): DWORD; stdcall;
function GetModuleHandle(lpModuleName: PChar): HMODULE; stdcall;

/// BPL loading functions
function LoadPackage(aSource: TMemoryStream; aLibFileName: String
{$IFDEF DELPHI2007}
    ;aValidatePackage: TValidatePackageProc = nil
{$ENDIF}
    ): TLibHandle; overload;
procedure UnloadPackage(Module: TLibHandle);

{$ELSE}
// DLL loading functions. They only forward the calls to the TMlLibraryManager instance
function LoadLibraryMem(aSource: TMemoryStream; aLibFileName: String = ''): TLibHandle;
procedure FreeLibraryMem(hModule: TLibHandle);
function GetProcAddressMem(hModule: TLibHandle; lpProcName: LPCSTR): FARPROC;
function FindResourceMem(hModule: TLibHandle; lpName, lpType: PChar): HRSRC;
function LoadResourceMem(hModule: TLibHandle; hResInfo: HRSRC): HGLOBAL;
function SizeOfResourceMem(hModule: TLibHandle; hResInfo: HRSRC): DWORD;
function GetModuleFileNameMem(hModule: TLibHandle): String;
function GetModuleHandleMem(ModuleName: String): TLibHandle;

/// BPL loading functions
function LoadPackageMem(aSource: TMemoryStream; aLibFileName: String; aValidatePackage: TValidatePackageProc = nil):
    TLibHandle; overload;
procedure UnloadPackageMem(Module: TLibHandle);
{$ENDIF MLHOOKED}

//TODO VG 090714: This method is used only to reset the loader during unit testing. Can be removed
{$IFDEF _CONSOLE_TESTRUNNER}
procedure UnloadAllLibraries;
{$ENDIF}

var
  MlOnDependencyLoad: TMlLoadDependentLibraryEvent;

implementation

const
  BASE_HANDLE = $1;  // The minimum value where the allocation of TLibHandle values begins

var
{$IFDEF MLHOOKED}
  Manager: TMlHookedLibraryManager;
{$ELSE}
  Manager: TMlLibraryManager;
{$ENDIF MLHOOKED}


{$IFDEF MLHOOKED}
{ ============ Hooked DLL Library memory functions ============ }
{ ============================================================= }

function LoadLibrary(aSource: TMemoryStream; lpLibFileName: PChar = nil): HMODULE;
begin
  Result := Manager.LoadLibraryMl(aSource, lpLibFileName);
end;

function LoadLibrary(lpLibFileName: PChar): HMODULE; stdcall;
begin
  Result := Manager.LoadLibraryMl(nil, lpLibFileName);
end;

function FreeLibrary(hModule: HMODULE): BOOL; stdcall;
begin
  Manager.FreeLibraryMl(hModule);
  Result := true;
end;

function GetProcAddress(hModule: HMODULE; lpProcName: LPCSTR): FARPROC; stdcall;
begin
  Result := Manager.GetProcAddressMl(hModule, lpProcName);
end;

function FindResource(hModule: HMODULE; lpName, lpType: PChar): HRSRC; stdcall;
begin
  Result := Manager.FindResourceMl(hModule, lpName, lpType);
end;

function LoadResource(hModule: HMODULE; hResInfo: HRSRC): HGLOBAL; stdcall;
begin
  Result := Manager.LoadResourceMl(hModule, hResInfo);
end;

function SizeofResource(hModule: HMODULE; hResInfo: HRSRC): DWORD; stdcall;
begin
  Result := Manager.SizeOfResourceMl(hModule, hResInfo);
end;

function GetModuleFileName(hModule: HINST; lpFilename: PChar; nSize: DWORD): DWORD; stdcall;
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

function GetModuleHandle(lpModuleName: PChar): HMODULE;
begin
  Result := Manager.GetModuleHandleMl(lpModuleName);
end;

{ ============ Hooked BPL Library memory functions ============ }
{ ====================================================== }

function LoadPackage(aSource: TMemoryStream; aLibFileName: String
{$IFDEF DELPHI2007}
    ;aValidatePackage: TValidatePackageProc = nil
{$ENDIF}) : TLibHandle;
begin
  Result := Manager.LoadPackageMl(aSource, aLibFileName, {$IFDEF DELPHI2007} aValidatePackage {$ELSE} nil {$ENDIF});
end;

procedure UnloadPackage(Module: TLibHandle);
begin
  Manager.UnloadPackageMl(Module);
end;


{$ELSE}
{ ============ Unhooked DLL Library memory functions ============ }
{ =============================================================== }

function LoadLibraryMem(aSource: TMemoryStream; aLibFileName: String = ''): TLibHandle;
begin
  Result := Manager.LoadLibraryMl(aSource, aLibFileName);
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

function GetModuleHandleMem(ModuleName: String): TLibHandle;
begin
  Result := Manager.GetModuleHandleMl(ModuleName);
end;


{ ============ BPL Library memory functions ============ }
{ ====================================================== }

function LoadPackageMem(aSource: TMemoryStream; aLibFileName: String; aValidatePackage: TValidatePackageProc = nil):
    TLibHandle;
begin
  Result := Manager.LoadPackageMl(aSource, aLibFileName, aValidatePackage);
end;

procedure UnloadPackageMem(Module: TLibHandle);
begin
  Manager.UnloadPackageMl(Module);
end;

{$ENDIF MLHOOKED}

//TODO VG 090714: This method is used only to reset the manager during unit testing. Can be removed
{$IFDEF _CONSOLE_TESTRUNNER}
procedure UnloadAllLibraries;
begin
  Manager.Free;
{$IFDEF MLHOOKED}
  Manager := TMlHookedLibraryManager.Create;
{$ELSE}
  Manager := TMlLibraryManager.Create;
{$ENDIF}
end;
{$ENDIF}

initialization
{$IFDEF MLHOOKED}
  Manager := TMlHookedLibraryManager.Create;
{$ELSE}
  Manager := TMlLibraryManager.Create;
{$ENDIF MLHOOKED}
  Manager.OnDependencyLoad := MlOnDependencyLoad;

finalization
  Manager.Free;

end.
