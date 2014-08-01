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

  PPackageInfoHeader = ^TPackageInfoHeader;
  TPackageInfoHeader = packed record
    Flags: Cardinal;
    RequiresCount: Integer;
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

type
  TBPLLoader = class(TMlBaseLoader)
  private
    function PackageInfoTable(Module: HMODULE): PPackageInfoHeader;
    procedure CheckForDuplicateUnits(Module: HMODULE; AValidatePackage: TValidatePackageProc);
    procedure InitializePackage(Module: HMODULE);
  public
    constructor Create; overload;
    constructor Create(aMem: TMemoryStream; aLibFileName: String); overload;
    procedure LoadFromStream(aMem: TMemoryStream; aLibFileName: String);
  end;

implementation

var
  SysInitHC: Cardinal;
  ValidatedUnitHashBuckets: TUnitHashBuckets;
  UnitHashBuckets: TUnitHashBuckets;

function HashName(Name: PChar): Cardinal;
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

function FindLibModule(Module: HModule): PLibModule; inline;
begin
  Result := LibModuleList;
  while Result <> nil do
  begin
    if Result.Instance = Cardinal(Module) then Exit;
    Result := Result.Next;
  end;
end;

function GetModuleName(Module: HMODULE): string;
var
  ModName: array[0..MAX_PATH] of Char;
begin
  SetString(Result, ModName, GetModuleFileName(Module, ModName, SizeOf(ModName)));
end;

function TBPLLoader.PackageInfoTable(Module: HMODULE): PPackageInfoHeader;
var
  ResInfo: HRSRC;
  Data: THandle;
begin
  Result := nil;
  ResInfo := Windows.FindResource(Module, 'PACKAGEINFO', RT_RCDATA);
  if ResInfo <> 0 then
  begin
    Data := LoadResource(ResInfo);
    if Data <> 0 then
      Result := PPackageInfoHeader(Data);
  end;
end;

procedure TBPLLoader.CheckForDuplicateUnits(Module: HMODULE; AValidatePackage: TValidatePackageProc);
var
  ModuleFlags: Cardinal;

  function IsUnitPresent(UnitName: PChar; HashCode: Cardinal; Module: HMODULE;
    const Buckets: TUnitHashBuckets; const ModuleName: string;
    var UnitPackage: string; ModuleHashCode: Cardinal): Boolean;
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
          UnitPackage := ChangeFileExt(ExtractFileName(
            GetModuleName(HMODULE(HashEntry.LibModule.Instance))), '');     // FIX
          Result := True;
          Exit;
        end;
        HashEntry := HashEntry.Next;
      end;
    end;
    Result := False;
  end;

  procedure InternalUnitCheck(Module: HModule);
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
    InfoTable := PackageInfoTable(Module);
    if (InfoTable <> nil) and (InfoTable.Flags and pfModuleTypeMask = pfPackageModule) then
    begin
      if ModuleFlags = 0 then
        ModuleFlags := InfoTable.Flags;
      LibModule := FindLibModule(Module);
      if (LibModule <> nil) and (LibModule.Reserved <> 0) then
        Exit;
      Validated := Assigned(AValidatePackage) and AValidatePackage(Module);
      ModuleName := ChangeFileExt(ExtractFileName(GetModuleName(Module)), '');   // FIX
      PkgName := PPkgName(Integer(InfoTable) + SizeOf(InfoTable^));
      Count := InfoTable.RequiresCount;
      for I := 0 to Count - 1 do
      begin
        InternalUnitCheck(GetModuleHandle(PChar(ChangeFileExt(PkgName^.Name, '.bpl'))));     // FIX
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
          with UName^ do
            // Test Flags to ignore weak package units
            if ((HC <> SysInitHC) or (StrIComp(Name, 'SysInit') <> 0)) and
            (Flags and ufWeakPackageUnit = 0) then
            begin
              // Always check against the unvalidated packages
              if IsUnitPresent(Name, HC, Module, UnitHashBuckets, ModuleName, UnitPackage, ModuleHC) or
              // if the package is not validateed also check it against the validated ones
                (not Validated and IsUnitPresent(Name, HC, Module, ValidatedUnitHashBuckets, ModuleName, UnitPackage, ModuleHC)) then
                raise EPackageError.CreateResFmt(@SDuplicatePackageUnit, [ModuleName, Name, UnitPackage]);
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
  InternalUnitCheck(Module);
end;

procedure TBPLLoader.InitializePackage(Module: HMODULE);
type
  TPackageLoad = procedure;
var
  PackageLoad: TPackageLoad;
begin
  CheckForDuplicateUnits(Module, nil);
  @PackageLoad := GetFunctionAddress('Initialize'); //Do not localize
  if Assigned(PackageLoad) then
    PackageLoad
  else
    raise EPackageError.CreateFmt(sInvalidPackageFile, [Name]); //VG 310714: Changed from original
end;

constructor TBPLLoader.Create;
begin
  inherited;
end;

constructor TBPLLoader.Create(aMem: TMemoryStream; aLibFileName: String);
begin
  Create;

  // Auto load the stream if one is passed. Otherwise it has to be loaded manually with LoadFromStream
  if Assigned(aMem) then
    LoadFromStream(aMem, aLibFileName)
  else
    raise EMlLibraryLoadError.Create('Can not load a library from an unassigned TStream');
end;

procedure TBPLLoader.LoadFromStream(aMem: TMemoryStream; aLibFileName: String);
begin
  if aLibFileName = '' then
    raise EMlLibraryLoadError.Create('The package file name can not be empty');
  inherited LoadFromStream(aMem);
  try
    Name := aLibFileName;
    InitializePackage(Cardinal(Handle));
  except
    Unload;
    raise;
  end;
end;

end.
