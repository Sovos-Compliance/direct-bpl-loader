{*******************************************************************************
*  Created by Vladimir Georgiev, 2014                                          *
*                                                                              *
*  Description:                                                                *
*  Unit implementing the TBPLLoader class that provides additional methods for *
*  loading BPLs. The code for the methods is based on the source of LoadPackage*
*  and UnloadPackage from the Embarcadero SysUtils unit                        *
*  The code handles the internal dependency of one package on another and      *
*  loading of the dependencies                                                 *
*                                                                              *
*  References:                                                                 *
*  http://stackoverflow.com/questions/7566954/why-code-in-any-unit-finalization-section-of-a-package-is-not-executed-at-start
*  http://hallvards.blogspot.com/2005/08/ultimate-delphi-ide-start-up-hack.html*
*******************************************************************************}

unit mlBPLLoader;

interface

uses
  Windows,
  SysUtils,
  SysConst,
  Classes,
  mlBaseLoader,
  mlTypes;

type
  PPackageInfoHeader = ^TPackageInfoHeader;
  TPackageInfoHeader = packed record
    Flags: Cardinal;
    RequiresCount: Integer;
  end;

const
  cBucketSize = 1021; // better distribution than 1024

type
  PPkgName = ^TPkgName;
  TPkgName = packed record
    HashCode: Byte;
    Name: array[0..255] of Char;
  end;

  PUnitName = ^TUnitName;
  TUnitName = packed record
    Flags : Byte;
    HashCode: Byte;
    Name: array[0..255] of Char;
  end;

  PUnitHashEntry = ^TUnitHashEntry;
  TUnitHashEntry = record
    Next, Prev: PUnitHashEntry;
    LibModule: PLibModule;
    UnitName: PChar;
    DupsAllowed: Boolean;
    FullHash: Cardinal;
  end;
  TUnitHashArray = array of TUnitHashEntry;
  TUnitHashBuckets = array[0..cBucketSize-1] of PUnitHashEntry;

  PModuleInfo = ^TModuleInfo;
  TModuleInfo = record
    Validated: Boolean;
    UnitHashArray: TUnitHashArray;
  end;

{$IFDEF VER130}
  TValidatePackageProc = function (Module: HMODULE): Boolean;
{$ENDIF VER130}

type
  TBPLLoader = class(TMlBaseLoader)
  private
    fPackageInitialized: Boolean;
    function HashName(Name: PChar): Cardinal;
    function FindLibModule(Module: HModule): PLibModule;
    function PackageInfoTable(Module: HMODULE; aSelfCheck: Boolean): PPackageInfoHeader;
    procedure CheckForDuplicateUnits(Module: HMODULE; aValidatePackage: TValidatePackageProc);
    procedure InitializePackage(Module: HMODULE; aValidatePackage: TValidatePackageProc);
    procedure FinalizePackage(Module: HMODULE);
    procedure ModuleUnloaded(Module: Longword);
  public
    constructor Create; overload;
    constructor Create(aMem: TMemoryStream; aLibFileName: String; aValidatePackage: TValidatePackageProc = nil); overload;
    destructor Destroy; override;
    procedure LoadFromStream(aMem: TMemoryStream; aLibFileName: String; aValidatePackage: TValidatePackageProc = nil);
    procedure Unload; overload;
  end;

implementation

uses
  mlLibraryManager;

var
  SysInitHC: Cardinal;
  ValidatedUnitHashBuckets: TUnitHashBuckets;
  UnitHashBuckets: TUnitHashBuckets;

{$IFDEF VER130}
function GetModuleName(Module: HMODULE): string;
var
  ModName: array[0..MAX_PATH] of Char;
begin
  SetString(Result, ModName, GetModuleFileName(Module, ModName, SizeOf(ModName)));
end;
{$ENDIF VER130}

function TBPLLoader.HashName(Name: PChar): Cardinal;
asm
  PUSH  ESI
  PUSH  EBX
  MOV   ESI, Name
  XOR   EAX, EAX

@@loop:
  ROL   EAX, 5
  MOV   BL, [ESI]
  CMP   BL, 0
  JE    @@done
  CMP   BL, 'A'
  JL    @@LowerCased
  CMP   BL, 'Z'
  JG    @@LowerCased
  OR    BL, 20H // make lower case
@@LowerCased:
  XOR   AL, BL
  INC   ESI
  JMP   @@loop
@@done:
  POP   EBX
  POP   ESI
  RET
end;

function TBPLLoader.FindLibModule(Module: HModule): PLibModule;
begin
  Result := LibModuleList;
  while Result <> nil do
  begin
    if Result.Instance = Cardinal(Module) then
      Exit;
    Result := Result.Next;
  end;
end;

/// Try to find the PACKAGEINFO resource to check the dependencies. Check the current module,
/// then a disk loaded, and then a mem loaded one
function TBPLLoader.PackageInfoTable(Module: HMODULE; aSelfCheck: Boolean): PPackageInfoHeader;
var
  ResInfo: HRSRC;
  Data: THandle;
begin
  Result := nil;
  try
    if aSelfCheck then
    begin
      ResInfo := FindResourceMl('PACKAGEINFO', RT_RCDATA);
      Data := LoadResourceMl(ResInfo);
    end else
    begin
      ResInfo := Windows.FindResource(Module, 'PACKAGEINFO', RT_RCDATA);
      if ResInfo <> 0 then
        Data := Windows.LoadResource(Module, ResInfo)
      else
      begin
        ResInfo := FindResourceMem(Module, 'PACKAGEINFO', RT_RCDATA);
        Data := LoadResourceMem(Module, ResInfo);
      end;
    end;
  except
    Data := 0;
  end;

  if Data <> 0 then
    Result := PPackageInfoHeader(Data);
end;

procedure TBPLLoader.CheckForDuplicateUnits(Module: HMODULE; aValidatePackage: TValidatePackageProc);
var
  ModuleFlags: Cardinal;

  function IsUnitPresent(UnitName: PChar; HashCode: Cardinal; Module: HMODULE; const Buckets: TUnitHashBuckets; const
      ModuleName: string; var UnitPackage: string; ModuleHashCode: Cardinal): Boolean;
  var
    HashEntry: PUnitHashEntry;
  begin
    if ((HashCode <> SysInitHC) or (StrIComp(UnitName, 'SysInit') <> 0)) and
    ((HashCode <> ModuleHashCode) or (StrIComp(UnitName, PChar(ModuleName)) <> 0)) then
    begin
      HashEntry := Buckets[HashCode mod cBucketSize];
      while HashEntry <> nil do
      begin
        if (HashEntry.DupsAllowed = (ModuleFlags and pfIgnoreDupUnits <> 0)) and
        ((HashEntry.FullHash = HashCode) and (StrIComp(UnitName, HashEntry.UnitName) = 0)) then
        begin
          // Get the module name that contains the duplicate unit. It could be either a disk or mem loaded one so try both
          UnitPackage := ChangeFileExt(ExtractFileName(GetModuleName(HMODULE(HashEntry.LibModule.Instance))), '');
          if UnitPackage = '' then
            try
              UnitPackage := ChangeFileExt(ExtractFileName(GetModuleFileNameMem(TLibHandle(HashEntry.LibModule.Instance))), '');
            except
              UnitPackage := '';
            end;
          Result := True;
          Exit;
        end;
        HashEntry := HashEntry.Next;
      end;
    end;
    Result := False;
  end;

  procedure InternalUnitCheck(Module: HModule; aSelfCheck: Boolean);
  var
    I, J: Integer;
    InfoTable: PPackageInfoHeader;
    UnitPackage: string;
    ModuleName: string;
    PkgName: PPkgName;
    UName: PUnitName;
    Count: Integer;
    LibModule: PLibModule;
    Validated: Boolean;
    HC: Cardinal;
    ModuleInfo: PModuleInfo;
    Buckets: ^TUnitHashBuckets;
    ModuleHC: Cardinal;
  begin
    InfoTable := PackageInfoTable(Module, aSelfCheck);
    if (InfoTable <> nil) and (InfoTable.Flags and pfModuleTypeMask = pfPackageModule) then
    begin
      if ModuleFlags = 0 then
        ModuleFlags := InfoTable.Flags;
      LibModule := FindLibModule(Module);
      if (LibModule <> nil) and (LibModule.Reserved <> 0) then
        Exit;
      Validated := Assigned(AValidatePackage) and AValidatePackage(Module);
      if aSelfCheck then
        ModuleName := ChangeFileExt(ExtractFileName(Name), '')
      else
        ModuleName := ChangeFileExt(ExtractFileName(GetExternalLibraryName(Module)), '');
      PkgName := PPkgName(Integer(InfoTable) + SizeOf(InfoTable^));
      Count := InfoTable.RequiresCount;
      for I := 0 to Count - 1 do
      begin
        InternalUnitCheck(GetExternalLibraryHandle(PChar(ChangeFileExt(PkgName^.Name, '.bpl'))), false); 
        Inc(Integer(PkgName), StrLen(PkgName.Name) + 2);
      end;
      Count := Integer(Pointer(PkgName)^);
      UName := PUnitName(Integer(PkgName) + 4);
      if LibModule <> nil then
      begin
        New(ModuleInfo);
        ModuleInfo.Validated := Validated;
        if Validated then
          Buckets := @ValidatedUnitHashBuckets
        else
          Buckets := @UnitHashBuckets;
        LibModule.Reserved := Integer(ModuleInfo);
        // don't include SysInit;
        SetLength(ModuleInfo.UnitHashArray, Count - 1);
        J := 0;
        ModuleHC := HashName(PChar(Pointer(ModuleName)));
        for I := 0 to Count - 1 do
        begin
          HC := HashName(UName.Name);
          // Test Flags to ignore weak package units
          if ((HC <> SysInitHC) or (StrIComp(UName^.Name, 'SysInit') <> 0)) and
          (UName^.Flags and ufWeakPackageUnit = 0) then
          begin
            // Always check against the unvalidated packages
            if IsUnitPresent(UName^.Name, HC, Module, UnitHashBuckets, ModuleName, UnitPackage, ModuleHC) or
            // if the package is not validateed also check it against the validated ones
              (not Validated and IsUnitPresent(UName^.Name, HC, Module, ValidatedUnitHashBuckets, ModuleName, UnitPackage, ModuleHC)) then
              raise EPackageError.CreateResFmt(@SDuplicatePackageUnit, [ModuleName, UName^.Name, UnitPackage]);
            ModuleInfo.UnitHashArray[J].UnitName := @UName.Name;
            ModuleInfo.UnitHashArray[J].LibModule := LibModule;
            ModuleInfo.UnitHashArray[J].DupsAllowed := InfoTable.Flags and pfIgnoreDupUnits <> 0;
            ModuleInfo.UnitHashArray[J].Prev := nil;
            ModuleInfo.UnitHashArray[J].FullHash := HC;
            HC := HC mod cBucketSize;
            ModuleInfo.UnitHashArray[J].Next := Buckets[HC];
            Buckets[HC] := @ModuleInfo.UnitHashArray[J];
            if ModuleInfo.UnitHashArray[J].Next <> nil then
              ModuleInfo.UnitHashArray[J].Next.Prev := Buckets[HC];
            Inc(J);
          end;
          Inc(Integer(UName), StrLen(UName.Name) + 3);
        end;
      end;
    end;
  end;

begin
  if SysInitHC = 0 then
    SysInitHC := HashName('SysInit');
  ModuleFlags := 0;
  InternalUnitCheck(Module, true);
end;

procedure TBPLLoader.InitializePackage(Module: HMODULE; aValidatePackage: TValidatePackageProc);
type
  TPackageLoad = procedure;
var
  PackageLoad: TPackageLoad;
begin
  CheckForDuplicateUnits(Module, aValidatePackage);
  @PackageLoad := GetFunctionAddress('Initialize'); //Do not localize
  if Assigned(PackageLoad) then
    PackageLoad
  else
    raise EPackageError.CreateFmt(sInvalidPackageFile, [Name]);
end;

procedure TBPLLoader.FinalizePackage(Module: HMODULE);
type
  TPackageUnload = procedure;
var
  PackageUnload: TPackageUnload;
begin
  @PackageUnload := GetFunctionAddress('Finalize'); //Do not localize
  if Assigned(PackageUnload) then
    PackageUnload
  else
    raise EPackageError.CreateRes(@sInvalidPackageHandle);
end;

procedure TBPLLoader.ModuleUnloaded(Module: Longword);
var
  LibModule: PLibModule;
  ModuleInfo: PModuleInfo;
  I: Integer;
  HC: Cardinal;
  Buckets: ^TUnitHashBuckets;
begin
  LibModule := FindLibModule(Module);
  if (LibModule <> nil) and (LibModule.Reserved <> 0) then
  begin
    ModuleInfo := PModuleInfo(LibModule.Reserved);
    if ModuleInfo.Validated then
      Buckets := @ValidatedUnitHashBuckets
    else
      Buckets := @UnitHashBuckets;
    for I := Low(ModuleInfo.UnitHashArray) to High(ModuleInfo.UnitHashArray) do
    begin
      if ModuleInfo.UnitHashArray[I].Prev <> nil then
        ModuleInfo.UnitHashArray[I].Prev.Next := ModuleInfo.UnitHashArray[I].Next
      else if ModuleInfo.UnitHashArray[I].UnitName <> nil then
      begin
        HC := HashName(ModuleInfo.UnitHashArray[I].UnitName) mod cBucketSize;
        if Buckets[HC] = @ModuleInfo.UnitHashArray[I] then
          Buckets[HC] := ModuleInfo.UnitHashArray[I].Next;
      end;
      if ModuleInfo.UnitHashArray[I].Next <> nil then
        ModuleInfo.UnitHashArray[I].Next.Prev := ModuleInfo.UnitHashArray[I].Prev;
    end;
    Dispose(ModuleInfo);
    LibModule.Reserved := 0;
  end;
end;

constructor TBPLLoader.Create;
begin
  inherited;
end;

constructor TBPLLoader.Create(aMem: TMemoryStream; aLibFileName: String; aValidatePackage: TValidatePackageProc = nil);
begin
  Create;

  // Auto load the stream if one is passed. Otherwise it has to be loaded manually with LoadFromStream
  if Assigned(aMem) then
    LoadFromStream(aMem, aLibFileName)
  else
    raise EMlLibraryLoadError.Create('Can not load a library from an unassigned TStream');
end;

destructor TBPLLoader.Destroy;
begin
  if Loaded then
    Unload;
  inherited;
end;

procedure TBPLLoader.LoadFromStream(aMem: TMemoryStream; aLibFileName: String; aValidatePackage: TValidatePackageProc =
    nil);
var
  LibModule: PLibModule;
begin
  if aLibFileName = '' then
    raise EMlLibraryLoadError.Create('The package file name can not be empty');

  if GetModuleHandle(PChar(aLibFileName)) <> 0 then
    raise EMlLibraryLoadError.CreateFmt('The %s package is already loaded from disk with the regular LoadPackage.' + #13#10 +
      ' Loading it again from memory will result in unpredicted behaviour.', [aLibFileName]);

  Assert(Handle <> 0, 'The Handle of a package must be assigned before loading it from a stream. It is used in RegisterModule');

  inherited LoadFromStream(aMem, aLibFileName);
  try
    // VG 040814: TODO: RegisterModule should be done automatically when the BPL is loaded from memory in the BaseLoader
    // Why doesn't it happen? Check and move this call in the base class.
    New(LibModule);
    ZeroMemory(LibModule, SizeOf(TLibModule));
    LibModule.Instance := Handle;
    RegisterModule(LibModule);

    InitializePackage(Cardinal(Handle), aValidatePackage);
    fPackageInitialized := true;
  except
    Unload;
    raise;
  end;
end;

procedure TBPLLoader.Unload;
var
  LibModule: PLibModule;
begin
  Assert(Handle <> 0, 'The Handle of a package must not be 0 when calling UnregisterModule');
  if fPackageInitialized then
    FinalizePackage(Handle);

  LibModule := FindLibModule(Handle);
  if Assigned(LibModule) then
  begin
    ModuleUnloaded(Handle);
    UnregisterModule(LibModule);
  end;

  inherited;
end;

end.
