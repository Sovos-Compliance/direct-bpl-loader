{***********************************************
*  Function for Shadow loading DLL from stream *
*  get import tables, redirection table        *
*  and fix GetProcAdrr  function               *
* =============================================*
*  Creating by Yuri Drigin (c) 2013 :          *
*      yuri.drigin@gmail.com                   *
*      yuri.drigin@hotmail.com                 *
*  Based on article of Max Gumerov :           *
* www.rsdn.ru//article/baseserv/peloader.xml   *
* =============================================================================*
*  Modified by Vladimir Georgiev, 2014                                         *
*                                                                              *
*  Description:                                                                *
*  Base class providing functionality for loading a PE image (DLL, EXE, SCR...)*
*  from memory instead of a file. It parses the PE headers, allocates memory,  *
*  gets a list of imported libs and exported functions and provides public     *
*  methods to access them like the GetProcAddress, FindResource, etc Win APIs  *
*                                                                              *
*  References:                                                                 *
*   http://www.joachim-bauch.de/tutorials/loading-a-dll-from-memory/           *
*   http://www.codeproject.com/Tips/431045/The-Inner-Working-of-FindResour     *
*   http://www.csn.ul.ie/~caolan/publink/winresdump/winresdump/doc/pefile2.html*
*   http://msdn.microsoft.com/en-us/magazine/cc301808.aspx                     *
*                                                                              *
*******************************************************************************}

{$I APIMODE.INC}

unit mlBaseLoader;

interface

uses
  Windows,
  Classes,
  SysUtils,
  JclPeImage,
  JclWin32,
  mlTypes,
  mlPEHeaders;

type
  /// <summary>TMlBaseLoader: Class that allows loading a single PE image from memory instead of a
  /// file. It emulates the LoadLibrary API and exposes methods to access the loaded
  /// image's exported functions, resources, etc
  /// </summary>
  TMlBaseLoader = class
  private
    fLoaded   : Boolean;
    fImageBase: Pointer;
    fHandle   : TLibHandle;
    fName     : String;
    fRefCount : Integer;
    fJclImage : TJclPeImage;
    fStream   : TMemoryStream;
    fOnDependencyLoad: TMlLoadDependentLibraryEvent;

    MyDLLProc           : TDLLEntryProc;
    ImageDOSHeader      : TImageDOSHeader;
    ImageNTHeaders      : TImageNTHeaders;
    Sections            : TSections;
    ImportArray         : TImports;
    ExportArray         : TExports;
    ExternalLibraryArray: TExternalLibrarys;

    // Helper functions
    function ConvertRVAToPointer(RVA: LongWord): Pointer;
    function ParseStringToNumber(aString: String): LongWord;

    // DLL parsing function
    function ReadImageHeaders  : Boolean;
    function InitializeImage   : Boolean;
    function ReadSections      : Boolean;
    function ProcessRelocations: Boolean;
    function ProcessImports    : Boolean;
    function ProtectSections   : Boolean;
    function ProcessExports    : Boolean;
    function ProcessResources  : Boolean;
    function InitializeLibrary : Boolean;

    function LoadExternalLibrary(LibraryName: String): HINST;
    function IsValidResHandle(hResInfo: HRSRC): Boolean;
  protected
    function GetExternalLibraryHandle(LibraryName: String): HINST;
    function GetExternalLibraryName(aLibHandle: HINST): String;
    function GetExternalLibraryProcAddress(aLibHandle: HINST; aProcName: PChar): FARPROC;
  public
    constructor Create(aMem: TMemoryStream; const aName: String = ''); overload;
    constructor Create; overload;
    destructor Destroy; override;

    procedure LoadFromStream(aMem: TMemoryStream; const aName: String = '');
    procedure Unload;

    function GetFunctionAddress(aName: String): Pointer;
    function FindResourceMl(lpName, lpType: PChar): HRSRC;
    function LoadResourceMl(hResInfo: HRSRC): HGLOBAL;
    function SizeOfResourceMl(hResInfo: HRSRC): DWORD;

    property Loaded          : Boolean                      read fLoaded           write fLoaded;
    property ImageBase       : Pointer                      read fImageBase;
    property Handle          : TLibHandle                   read fHandle           write fHandle;
    property Name            : String                       read fName;
    property RefCount        : Integer                      read fRefCount         write fRefCount;
    property OnDependencyLoad: TMlLoadDependentLibraryEvent read fOnDependencyLoad write fOnDependencyLoad;
  end;                                

implementation

uses
  mlLibrary;

/// Convert a Relative Virtual Address to an absolute pointer
function TMlBaseLoader.ConvertRVAToPointer(RVA: LongWord): Pointer;
var
  I : Integer;
begin
  Result := nil;
  for I := Low(Sections) to High(Sections) do begin
    if (RVA < (Sections[I].RVA + Sections[I].Size)) and (RVA >= Sections[I].RVA) then begin
      Result := Pointer(LongWord((RVA - LongWord(Sections[I].RVA)) + LongWord(Sections[I].Base)));
      Exit;
    end;
  end;
end;

function TMlBaseLoader.ParseStringToNumber(aString: String): LongWord;
var
  CharCounter: Integer;
begin
  Result := 0;
  for CharCounter := 0 to length(aString) - 1 do
  begin
    if aString[CharCounter] in ['0'..'9'] then
      Result := (Result * 10) + BYTE(BYTE(aString[CharCounter]) - BYTE('0'))
    else
      Exit;
  end;
end;

/// Read the PE image DOS and NT headers and check if they have valid signatures and lengths
function TMlBaseLoader.ReadImageHeaders: Boolean;
begin
  Result := False;
  if fStream.Size > 0 then
  begin
    fStream.Seek(0, soFromBeginning);
    FillChar(ImageNTHeaders, SizeOf(TImageNTHeaders), #0);
    if fStream.Read(ImageDOSHeader, SizeOf(TImageDOSHeader)) <> SizeOf(TImageDOSHeader) then
      Exit;
    if ImageDOSHeader.Signature <> $5A4D then
      Exit;
    if fStream.Seek(ImageDOSHeader.LFAoffset, soFromBeginning) <> LONGINT(ImageDOSHeader.LFAoffset) then
      Exit;
    if fStream.Read(ImageNTHeaders.Signature, SizeOf(LongWord)) <> SizeOf(LongWord) then
      Exit;
    if ImageNTHeaders.Signature <> $00004550 then
      Exit;
    if fStream.Read(ImageNTHeaders.FileHeader, SizeOf(TImageFileHeader)) <> SizeOf(TImageFileHeader) then
      Exit;
    if ImageNTHeaders.FileHeader.Machine <> $14C then
      Exit;
    if fStream.Read(ImageNTHeaders.OptionalHeader, ImageNTHeaders.FileHeader.SizeofOptionalHeader) <> ImageNTHeaders.FileHeader.SizeofOptionalHeader then
      Exit;
    Result := True;
  end;
end;

/// Load the PE image and its sections from the fStream into memory from where it will be executed
/// Also initialize the pointers to the image base (first memory byte where the image is loaded)
function TMlBaseLoader.InitializeImage: Boolean;
var
  SectionBase: Pointer;
  OldPosition: Integer;
  OldProtect : LongWord;
begin
  Result := False;
  if ImageNTHeaders.FileHeader.NumberofSections > 0 then
  begin
    fImageBase  := VirtualAlloc(nil, ImageNTHeaders.OptionalHeader.SizeofImage, MEM_RESERVE, PAGE_READWRITE);
    SectionBase := VirtualAlloc(fImageBase, ImageNTHeaders.OptionalHeader.SizeofHeaders, MEM_COMMIT, PAGE_READWRITE);
    if not Assigned(fImageBase) or not Assigned(SectionBase) then
      raise EMlLibraryLoadError.Create('Could not allocate memory: ' + SysErrorMessage(GetLastError));
    OldPosition := fStream.Position;
    fStream.Seek(0, soFromBeginning);
    fStream.Read(SectionBase^, ImageNTHeaders.OptionalHeader.SizeofHeaders);
    if not VirtualProtect(SectionBase, ImageNTHeaders.OptionalHeader.SizeofHeaders, PAGE_READONLY, OldProtect) then
      raise EMlLibraryLoadError.Create('Could not protect memory: ' + SysErrorMessage(GetLastError));
    fStream.Seek(OldPosition, soFromBeginning);
    Result := True;
  end;
end;

/// Read all the PE sections from the fStream, allocate memory for each one and load them.
/// Initialize the Sections array with their count, virtual addresses(RVA), size, etc
function TMlBaseLoader.ReadSections: Boolean;
var
  I             : Integer;
  Section       : TImageSectionHeader;
  SectionHeaders: PImageSectionHeaders;
begin
  Result := False;
  if ImageNTHeaders.FileHeader.NumberOfSections > 0 then
  begin
    GetMem(SectionHeaders, ImageNTHeaders.FileHeader.NumberOfSections * SizeOf(TImageSectionHeader));
    if fStream.Read(SectionHeaders^, (ImageNTHeaders.FileHeader.NumberOfSections * SizeOf(TImageSectionHeader))) <> (ImageNTHeaders.FileHeader.NumberofSections * SIZEof(TImageSectionHeader)) then
      Exit;
    SetLength(Sections, ImageNTHeaders.FileHeader.NumberOfSections);
    for I := 0 to ImageNTHeaders.FileHeader.NumberOfSections - 1 do
    begin
      Section          := SectionHeaders^[I];
      Sections[I].RVA  := Section.VirtualAddress;
      Sections[I].Size := Section.SizeofRawData;
      if Sections[I].Size < Section.Misc.VirtualSize then
      begin
        Sections[I].Size := Section.Misc.VirtualSize;
      end;
      Sections[I].Characteristics := Section.Characteristics;
      Sections[I].Base := VirtualAlloc(Pointer(LongWord(Sections[I].RVA + LongWord(fImageBase))), Sections[I].Size, MEM_COMMIT, PAGE_READWRITE);
      if not Assigned(Sections[I].Base) then
        raise EMlLibraryLoadError.Create('Could not allocate section memory: ' + SysErrorMessage(GetLastError));
      FillChar(Sections[I].Base^, Sections[I].Size, #0);
      if Section.PointertoRawData <> 0 then
      begin
        fStream.Seek(Section.PointertoRawData, sofrombeginning);
        if fStream.Read(Sections[I].Base^, Section.SizeofRawData) <> LONGINT(Section.SizeofRawData) then
          Exit;
      end;
    end;
    FreeMem(SectionHeaders);
    Result := True;
  end;
end;

/// All memory addresses in the code and data sections of a library are stored relative to the address
/// where the image is loaded (defined by ImageBase in the OptionalHeader). If the library can’t be
/// imported to this memory address, the references must get adjusted => relocated.
function TMlBaseLoader.ProcessRelocations: Boolean;
var
  Relocations        : PChar;
  Position           : LongWord;
  BaseRelocation     : PImageBaseRelocation;
  Base               : Pointer;
  NumberofRelocations: LongWord;
  Relocation         : PWordArray;
  RelocationCounter  : Longint;
  RelocationPointer  : Pointer;
  RelocationType     : LongWord;
begin
  Result := False;
  if ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress <> 0 then
  begin
    Relocations := ConvertRVAToPointer(ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress);
    Position := 0;
    while Assigned(Relocations) and (Position < ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size) do
    begin
      BaseRelocation := PImageBaseRelocation(Relocations);
      Base := ConvertRVAToPointer(BaseRelocation^.VirtualAddress);
      if not Assigned(Base) then
        Exit;
      NumberofRelocations := (BaseRelocation^.SizeofBlock - SizeOf(TImageBaseRelocation)) div SizeOf(WORD);
      Relocation := Pointer(LongWord(LongWord(BaseRelocation) + SizeOf(TImageBaseRelocation)));
      for RelocationCounter := 0 to NumberofRelocations - 1 do
      begin
        RelocationPointer := Pointer(LongWord(LongWord(Base) + (Relocation^[RelocationCounter] and $FFF)));
        RelocationType := Relocation^[RelocationCounter] shr 12;
        case RelocationType of
          IMAGE_REL_BASED_ABSOLUTE: ;
          IMAGE_REL_BASED_HIGH:
            PWord(RelocationPointer)^ := (LongWord(((LongWord(PWord(RelocationPointer)^ + LongWord(fImageBase) - ImageNTHeaders.OptionalHeader.ImageBase)))) shr 16) and $FFFF;
          IMAGE_REL_BASED_LOW:
            PWord(RelocationPointer)^ := LongWord(((LongWord(PWord(RelocationPointer)^ + LongWord(fImageBase) - ImageNTHeaders.OptionalHeader.ImageBase)))) and $FFFF;
          IMAGE_REL_BASED_HIGHLOW:
            PPointer(RelocationPointer)^ := Pointer((LongWord(LongWord(PPointer(RelocationPointer)^) + LongWord(fImageBase) - ImageNTHeaders.OptionalHeader.ImageBase)));
          IMAGE_REL_BASED_HIGHADJ: ; // ???
          IMAGE_REL_BASED_MIPS_JMPADDR: ; // Only for MIPS CPUs ;)
        end;
      end;
      Relocations := Pointer(LongWord(LongWord(Relocations) + BaseRelocation^.SizeOfBlock));
      Inc(Position, BaseRelocation^.SizeOfBlock);
    end;
    Result := True;
  end;
end;

/// Read the IMPORT sections (functions from other DLLs that this one uses)
function TMlBaseLoader.ProcessImports : Boolean;
var
  ImportDescriptor : PImageImportDescriptor;
  ThunkData        : PLongWord;
  Name             : PChar;
  DLLImport        : PDLLImport;
  DLLfunctionImport: PDLLfunctionImport;
  functionPointer  : Pointer;
  LibHandle        : HINST;
begin
  if ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress <> 0 then
  begin
    ImportDescriptor := ConvertRVAToPointer(ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);
    if Assigned(ImportDescriptor) then
    begin
      SetLength(ImportArray, 0);
      while ImportDescriptor^.Name <> 0 do
      begin
        Name := ConvertRVAToPointer(ImportDescriptor^.Name);
        SetLength(ImportArray, Length(ImportArray) + 1);
        LibHandle := LoadExternalLibrary(Name);
        DLLImport := @ImportArray[Length(ImportArray) - 1];
        DLLImport^.LibraryName   := Name;
        DLLImport^.LibraryHandle := LibHandle;
        DLLImport^.Entries       := nil;
        if ImportDescriptor^.TimeDateStamp = 0 then
          ThunkData := ConvertRVAToPointer(ImportDescriptor^.FirstThunk)
        else
          ThunkData := ConvertRVAToPointer(ImportDescriptor^.OriginalFirstThunk);
        while ThunkData^ <> 0 do
        begin
          SetLength(DLLImport^.Entries, Length(DLLImport^.Entries) + 1);
          DLLfunctionImport := @DLLImport^.Entries[Length(DLLImport^.Entries) - 1];
          if (ThunkData^ and IMAGE_ORDINAL_FLAG32) <> 0 then
          begin
            DLLfunctionImport^.NameOrID := niID;
            DLLfunctionImport^.ID       := ThunkData^ and IMAGE_ORDINAL_MASK32;
            DLLfunctionImport^.Name     := '';
            functionPointer := GetExternalLibraryProcAddress(DLLImport^.LibraryHandle, PCHAR(ThunkData^ and IMAGE_ORDINAL_MASK32));
          end else
          begin
            Name := ConvertRVAToPointer(LongWord(ThunkData^) + IMPORTED_NAME_OFFSET);
            DLLfunctionImport^.NameOrID := niName;
            DLLfunctionImport^.ID       := 0;
            DLLfunctionImport^.Name     := Name;
            functionPointer := GetExternalLibraryProcAddress(DLLImport^.LibraryHandle, Name);
          end;

          if not Assigned(functionPointer) then
            raise EMlLibraryLoadError.CreateFmt('Could not find the address of imported function "%s", Library "%s"', [Name, DLLImport^.LibraryName]);
          PPointer(Thunkdata)^ := functionPointer;
          Inc(ThunkData);
        end;
        Inc(ImportDescriptor);
      end;
    end;
  end;
  Result := True;
end;

/// Protect the memory where the image and sections are loaded by limiting the access to the different
/// memory pages. E.g. some pages get READ, WRITE, EXECUTE, etc access or a combination
function TMlBaseLoader.ProtectSections: Boolean;
var
   I: integer;
   Characteristics: LongWord;
   Flags: LongWord;
   OldProtect: LongWord;
begin
  Result := False;
  if ImageNTHeaders.FileHeader.NumberofSections > 0 then
  begin
    for I := 0 to ImageNTHeaders.FileHeader.NumberofSections - 1 do
    begin
      Characteristics := Sections[I].Characteristics;
      Flags := 0;
      if (Characteristics and IMAGE_SCN_MEM_EXECUTE) <> 0 then
      begin
        if (Characteristics and IMAGE_SCN_MEM_READ) <> 0 then
        begin
          if (Characteristics and IMAGE_SCN_MEM_WRITE) <> 0 then
            Flags := Flags or PAGE_EXECUTE_READWRITE
          else
            Flags := Flags or PAGE_EXECUTE_READ;
        end else
          if (Characteristics and IMAGE_SCN_MEM_WRITE) <> 0 then
            Flags := Flags or PAGE_EXECUTE_WRITECOPY
          else
            Flags := Flags or PAGE_EXECUTE;
      end else if (Characteristics and IMAGE_SCN_MEM_READ) <> 0 then begin
        if (Characteristics and IMAGE_SCN_MEM_WRITE) <> 0 then begin
          Flags := Flags or PAGE_READWRITE;
        end else begin
          Flags := Flags or PAGE_READONLY;
        end;
      end else if (Characteristics and IMAGE_SCN_MEM_WRITE) <> 0 then begin
        Flags := Flags or PAGE_WRITECOPY;
      end else begin
        Flags := Flags or PAGE_NOACCESS;
      end;
      if (Characteristics and IMAGE_SCN_MEM_NOT_CACHED) <> 0 then begin
        Flags := Flags or PAGE_NOCACHE;
      end;
      if not VirtualProtect(Sections[I].Base, Sections[I].Size, Flags, OldProtect) then
        raise EMlLibraryLoadError.Create('Could not protect section memory');
    end;
    Result := True;
  end;
end;

/// Process the EXPORT section and get a list of all the functions this library exports
/// Add their names, indexes and pointers to the ExportArray so they can be used later upon request by GetFunctionAddress
function TMlBaseLoader.ProcessExports: Boolean;
var
  I: Integer;
  ExportDirectory       : PImageExportDirectory;
  ExportDirectorySize   : LongWord;
  functionNamePointer   : Pointer;
  functionName          : PChar;
  functionIndexPointer  : Pointer;
  functionIndex         : LongWord;
  functionPointer       : Pointer;
  forwarderCharPointer  : PChar;
  forwarderstring       : string;
  forwarderLibrary      : string;
  forwarderLibraryHandle: HINST;
begin
  if ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress <> 0 then
  begin
    ExportDirectory := ConvertRVAToPointer(ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    if Assigned(ExportDirectory) then
    begin
       ExportDirectorySize := ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].Size;
       SetLength(ExportArray, ExportDirectory^.NumberofNames);
       for I := 0 to ExportDirectory^.NumberofNames - 1 do
       begin
          functionNamePointer  := ConvertRVAToPointer(LongWord(ExportDirectory^.AddressofNames));
          functionNamePointer  := ConvertRVAToPointer(PLongWordArray(functionNamePointer)^[I]);
          functionName         := functionNamePointer;
          functionIndexPointer := ConvertRVAToPointer(LongWord(ExportDirectory^.AddressofNameOrdinals));
          functionIndex        := PWordarray(functionIndexPointer)^[I];
          functionPointer      := ConvertRVAToPointer(LongWord(ExportDirectory^.Addressoffunctions));
          functionPointer      := ConvertRVAToPointer(PLongWordarray(functionPointer)^[functionIndex]);
          ExportArray[I].Name  := functionName;
          ExportArray[I].Index := functionIndex;
          if (LongWord(ExportDirectory) < LongWord(functionPointer)) and (LongWord(functionPointer) < (LongWord(ExportDirectory) + ExportDirectorySize)) then
          begin
            forwarderCharPointer := functionPointer;
            forwarderstring      := forwarderCharPointer;
            while forwarderCharPointer^ <> '.' do
              Inc(forwarderCharPointer);

            forwarderLibrary := Copy(forwarderstring, 1, POS('.', forwarderstring) - 1);
            LoadExternalLibrary(forwarderLibrary);
            forwarderLibraryHandle := GetExternalLibraryHandle(forwarderLibrary);

            if forwarderCharPointer^ = '#' then
            begin
              Inc(forwarderCharPointer);
              forwarderstring      := forwarderCharPointer;
              forwarderCharPointer := ConvertRVAToPointer(ParsestringtoNumber(forwarderstring));
              forwarderstring      := forwarderCharPointer;
            end
            else
            begin
              forwarderstring := forwarderCharPointer;
              ExportArray[I].functionPointer := GetExternalLibraryProcAddress(forwarderLibraryHandle, PCHAR(forwarderstring));
            end;
          end
          else
          begin
            ExportArray[I].functionPointer := functionPointer;
          end;
          if not Assigned(ExportArray[I].functionPointer) then
            raise EMlLibraryLoadError.CreateFmt('Can not find address for exported function: %s', [ExportArray[I].Name]);
       end
    end;
  end;
  Result := True;
end;

/// Build the resource list with the help of TJclPeImage.ResourceList to be used when requested by
/// FindResource, LoadResource, SizeOfResource
function TMlBaseLoader.ProcessResources: Boolean;
begin
  // Just used to make the fJclImage preload the resources list and check if there are any issues
  Result := fJclImage.ResourceList <> nil;
end;

/// Notify the library that it is loaded by calling the DLL Entry function
function TMlBaseLoader.InitializeLibrary: Boolean;
begin
  Result := False;

  @MyDLLProc := ConvertRVAToPointer(ImageNTHeaders.OptionalHeader.AddressOfEntryPoint);
  if not Assigned(MyDLLProc) then
    raise EMlLibraryLoadError.Create('Unable to find library EntryProc');
  if MyDLLProc(Cardinal(fImageBase), DLL_PROCESS_ATTACH, nil) then
    Result := True;
end;

/// Check if an external dependency is already loaded and load it if not
/// Fire the OnDependencyLoad event and load the library from drive or memory(or discard)
/// depending on the event params
/// The optionally passed MemStream can be freed after loading from it
function TMlBaseLoader.LoadExternalLibrary(LibraryName: String): HINST;
var
  LoadAction: TLoadAction;
  MemStream : TMemoryStream;
  FreeStream: Boolean;
  Source    : TExternalLibrarySource;
begin
  // Check the array of already loaded external libraries
  Result := GetExternalLibraryHandle(LibraryName);

  // Not in the array, so we have to load it
  if Result = 0 then
  begin
    // Check if the external is already loaded from disk or memory, but by another module
    // In case it is found, load it again to increase the reference count to show that this module is using it
    // Otherwise the other module that used the external might unload it, while it is used by this module

    // Check the standard API
    Result := GetModuleHandle(PChar(LibraryName));
    if Result <> 0 then
    begin
      Result := Windows.LoadLibrary(PChar(LibraryName));  // Inc the reference count
      // Check the result again because there is a slight chance that the lib got deleted between the GetModuleHandle and LoadLibrary calls (very unlikely)
      if Result = 0 then
        raise EMlLibraryLoadError.CreateFmt('Required library %s could not be loaded. OS Error: %s',
          [LibraryName, SysErrorMessage(GetLastError)]);
      Source := lsHardDisk;
    end else
    begin
      // Check the Mem API
{$IFDEF MLHOOKED}
      Result := GetModuleHandle(PChar(LibraryName));
{$ELSE}
      Result := GetModuleHandleMem(LibraryName);
{$ENDIF MLHOOKED}
      if Result <> 0 then
      begin
{$IFDEF MLHOOKED}
        Result := LoadLibrary(nil, PChar(LibraryName)); // No need to pass a mem stream. This will just increase the ref count
{$ELSE}
        Result := LoadLibraryMem(nil, LibraryName); // No need to pass a mem stream. This will just increase the ref count
{$ENDIF MLHOOKED}
        Source := lsMemStream;
      end else
      begin
        // Not loaded from either Disk or Mem, so call the event and load the library
        LoadAction := laHardDisk;
        MemStream  := nil;
        FreeStream := false;
        if Assigned(fOnDependencyLoad) then
          fOnDependencyLoad(fName, LibraryName, LoadAction, MemStream, FreeStream);

        Source := lsHardDisk;
        case LoadAction of
          laHardDisk:
            begin
              // Load the external as a BPL or a DLL
              // VG 140814: This needs more investigation. Original LoadPackage uses LoadLibrary to load dependencies
              // but in our case this leads to items in the UnitHashBuckets array not being cleared and AVs
              if UpperCase(ExtractFileExt(LibraryName)) = '.BPL' then
                Result := LoadPackage(LibraryName)
              else
                Result := Windows.LoadLibrary(PChar(LibraryName));
              if Result = 0 then
                raise EMlLibraryLoadError.CreateFmt('Required library %s could not be loaded. OS Error: %s',
                  [LibraryName, SysErrorMessage(GetLastError)]);
              Source := lsHardDisk;
            end;
          laMemStream:
            begin
              // Load the external as a BPL or a DLL. See comment above
{$IFDEF MLHOOKED}
              if UpperCase(ExtractFileExt(LibraryName)) = '.BPL' then
                Result := LoadPackageMem(MemStream, LibraryName)
              else
                Result := LoadLibrary(MemStream, PChar(LibraryName));
{$ELSE}
              if UpperCase(ExtractFileExt(LibraryName)) = '.BPL' then
                Result := LoadPackageMem(MemStream, LibraryName)
              else
                Result := LoadLibraryMem(MemStream, LibraryName);
{$ENDIF MLHOOKED}
              Source := lsMemStream;
              if FreeStream then
                FreeAndNil(MemStream);
            end;
          laDiscard:  //VG 010814: TODO: Is this really necessary? What usage would it have?
            begin
              Exit;
            end;
        end;
      end;
    end;

    SetLength(ExternalLibraryArray, Length(ExternalLibraryArray) + 1);
    ExternalLibraryArray[High(ExternalLibraryArray)].LibrarySource := Source;
    ExternalLibraryArray[High(ExternalLibraryArray)].LibraryName   := LibraryName;
    ExternalLibraryArray[High(ExternalLibraryArray)].LibraryHandle := Result;
  end;
end;

function TMlBaseLoader.GetExternalLibraryHandle(LibraryName: String): HINST;
var
  I : Integer;
begin
  Result := 0;
  for I := 0 to Length(ExternalLibraryArray) - 1 do
  begin
    if ExternalLibraryArray[I].LibraryName = LibraryName then
    begin
      Result := ExternalLibraryArray[I].LibraryHandle;
      Exit;
    end;
  end;
end;

function TMlBaseLoader.GetExternalLibraryName(aLibHandle: HINST): String;
var
  I : Integer;
begin
  Result := '';
  for I := 0 to Length(ExternalLibraryArray) - 1 do
  begin
    if ExternalLibraryArray[I].LibraryHandle = aLibHandle then
    begin
      Result := ExternalLibraryArray[I].LibraryName;
      Exit;
    end;
  end;
end;

/// The HRSRS is a pointer to the resource's PImageResourceDataEntry in memory
/// Validate if it is a valid pointer in the bounds of the RESOURCE section
function TMlBaseLoader.IsValidResHandle(hResInfo: HRSRC): Boolean;
  procedure CheckItem(aItem: TJclPeResourceItem);
  var
    I: Integer;
  begin
    if aItem.IsDirectory then
      for I := 0 to aItem.List.Count - 1 do
        CheckItem(aItem.List[I])
    else
      if HRSRC(aItem.DataEntry) = hResInfo then
        Result := true;
  end;
var
  I: Integer;
  ResSectionVA: Cardinal;
begin
  ResSectionVA := Cardinal(ConvertRVAToPointer(ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE].VirtualAddress));
  Result := (hResInfo >= ResSectionVA) and (hResInfo < (ResSectionVA) + ImageNTHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE].Size);

  // If the pointer is in the RESOURCE section make an additional check that it points to a PImageResourceDataEntry
  if  (fJclImage.ResourceList.Count > 0) then
  begin
    Result := false;
    for I := 0 to fJclImage.ResourceList.Count - 1 do
    begin
      CheckItem(fJclImage.ResourceList[I]);
      if Result then
        Exit;
    end;
  end;
end;

constructor TMlBaseLoader.Create(aMem: TMemoryStream; const aName: String = '');
begin
  Create;

  // Auto load the stream if one is passed. Otherwise it has to be loaded manually with LoadFromStream
  LoadFromStream(aMem, aName);
end;

constructor TMlBaseLoader.Create;
begin
  inherited Create;
  fJclImage := TJclPeImage.Create;
end;

destructor TMlBaseLoader.Destroy;
begin
  if fLoaded then
    Unload;
  fJclImage.Free;

  inherited Destroy;
end;

/// Main method to load the library in memory and process the sections, imports, exports, resources, etc
procedure TMlBaseLoader.LoadFromStream(aMem: TMemoryStream; const aName: String = '');
begin
  if fLoaded then
    raise EMlLibraryLoadError.Create('There is a loaded library. Please unload it first');

  if not Assigned(aMem) then
    raise EMlLibraryLoadError.Create('Can not load a library from an unassigned stream');

  if aMem.Size = 0 then
    raise EMlLibraryLoadError.Create('Can not load a library from an empty stream');

  fLoaded := False;
  fName := ExtractFileName(aName); // Only the name is used, because this is compared later when loading external dependant libraries

  fStream := aMem;
  if fStream.Size > 0 then
    if ReadImageHeaders then
      if InitializeImage then
        if ReadSections then
          if ProcessRelocations then
            if ProcessImports then
              if ProcessExports then
                if ProcessResources then
                  if ProtectSections then
                    fLoaded := InitializeLibrary;
  fStream := nil;

  if fLoaded then
    fJclImage.AttachLoadedModule(Cardinal(fImageBase))
  else
  begin
    Unload;
    raise EMlLibraryLoadError.Create('Library could not be loaded from memory');
  end;
end;

/// Unload the library, free the memory and reset all the arrays with exports, imports, resources, etc
procedure TMlBaseLoader.Unload;
var
  I, J: integer;
begin
  // Reset the link of the JCL image to the loaded library
  fJclImage.AttachLoadedModule(0);

  if Assigned(MyDLLProc) then
    MyDLLProc(Cardinal(fImageBase), DLL_PROCESS_DETACH, nil);
  MyDLLProc := nil;

  for I := 0 to length(Sections) - 1 do
  begin
    if Assigned(Sections[I].Base) then
      VirtualFree(Sections[I].Base, 0, MEM_RELEASE);
  end;
  SetLength(Sections, 0);

  // Unload the external dependency libraries
  for I := 0 to Length(ExternalLibraryArray) - 1 do
  begin
    if ExternalLibraryArray[I].LibrarySource = lsHardDisk then
      Win32Check(FreeLibrary(ExternalLibraryArray[I].LibraryHandle))
    else
    begin
{$IFDEF MLHOOKED}
      if UpperCase(ExtractFileExt(ExternalLibraryArray[I].LibraryName)) = '.BPL' then
        UnloadPackage(ExternalLibraryArray[I].LibraryHandle)
      else
        FreeLibrary(ExternalLibraryArray[I].LibraryHandle);
{$ELSE}
      if UpperCase(ExtractFileExt(ExternalLibraryArray[I].LibraryName)) = '.BPL' then
        UnloadPackageMem(ExternalLibraryArray[I].LibraryHandle)
      else
        FreeLibraryMem(ExternalLibraryArray[I].LibraryHandle);
{$ENDIF MLHOOKED}
    end;
  end;
  SetLength(ExternalLibraryArray, 0);

  for I := 0 to Length(ImportArray) - 1 do
  begin
    for J := 0 to Length(ImportArray[I].Entries) - 1 do
      ImportArray[I].Entries[J].Name := '';
    SetLength(ImportArray[I].Entries, 0);
  end;
  SetLength(ImportArray, 0);

  for I := 0 to Length(Exportarray) - 1 do
    Exportarray[I].Name := '';
  SetLength(Exportarray, 0);

  VirtualFree(fImageBase, 0, MEM_RELEASE);

  fLoaded := false;
  fName   := '';
  fHandle := 0;
end;

/// Return a pointer to an exported function from the loaded image like GetProcAddress API
function TMlBaseLoader.GetFunctionAddress(aName: String): Pointer;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Length(ExportArray) - 1 do
    if ExportArray[I].Name = aName then
    begin
      Result := ExportArray[I].functionPointer;
      Exit;
    end;
  if Result = nil then
    raise EMlProcedureError.Create('Procedure not found in library');
end;

/// Find the resource requested and return a pointer to its data structure
/// The HRSRC result is just a pointer to a IMAGE_RESOURCE_DATA_ENTRY record passed to
/// LoadResource and SizeOfResource
function TMlBaseLoader.FindResourceMl(lpName, lpType: PChar): HRSRC;
var
  Resource: TJclPeResourceItem;
begin
  Result := 0;
  Resource := fJclImage.ResourceList.FindResource(lpType, lpName);
  if Assigned(Resource) then
  begin
    // Find the leaf node in the resouce tree, which might contain a number of entries for different languages
    while Resource.IsDirectory and (Resource.List.Count > 0) do
      Resource := Resource.List[0];
    Result := HRSRC(Resource.DataEntry);
  end;
end;

/// Get a proc address, checking if the external lib is loaded from disk or mem
function TMlBaseLoader.GetExternalLibraryProcAddress(aLibHandle: HINST; aProcName: PChar): FARPROC;
var
  I : Integer;
begin
  Result := nil;
  for I := 0 to Length(ExternalLibraryArray) - 1 do
  begin
    if ExternalLibraryArray[I].LibraryHandle = aLibHandle then
    begin
      if ExternalLibraryArray[I].LibrarySource = lsHardDisk then
        Result := GetProcAddress(aLibHandle, aProcName)
      else
{$IFDEF MLHOOKED}
        Result := GetProcAddress(aLibHandle, aProcName);
{$ELSE}
        Result := GetProcAddressMem(aLibHandle, aProcName);
{$ENDIF MLHOOKED}
      Exit;
    end;
  end;
end;

/// Return a pointer to the actual resource data in memory
function TMlBaseLoader.LoadResourceMl(hResInfo: HRSRC): HGLOBAL;
begin
  if IsValidResHandle(hResInfo) then
    Result := HGLOBAL(fJclImage.RvaToVa(PImageResourceDataEntry(hResInfo).OffsetToData))
  else
    raise EMlResourceError.Create('Invalid resource info handle');
end;

/// Calculate the size of the resource passed
function TMlBaseLoader.SizeOfResourceMl(hResInfo: HRSRC): DWORD;
begin
  if IsValidResHandle(hResInfo) then
    Result := PImageResourceDataEntry(hResInfo).Size
  else
    raise EMlResourceError.Create('Invalid resource info handle');
end;

end.
