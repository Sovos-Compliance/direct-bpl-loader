unit PEImage;

interface
uses
  Windows,
  Classes,
  SysUtils,
  ImportsTable;

const
  IMAGE_ORDINAL_FLAG32 = $80000000;
  IMAGE_ORDINAL_MASK32 = $7FFFFFFF;
  IMPORTED_NAME_OFFSET = $00000002;

Type

  EPEImageException = class(Exception);

  PImportFunction = ^TImportFunction;
  TImportFunction = record
    ID : Cardinal; // ID  ( Zero if exports by name)
    Name : string; // name of function in library
  end;

  PImportFuncArray = ^TImportFuncArray;
  TImportFuncArray = array of TImportFunction;

  PImportsLib = ^TImportsLib;
  TImportsLib = record
    Name : string; // Name of external library
    imports : TImportFuncArray;
  end;

  TImportsArray = array of TImportsLib;

  // PE Image
  THJPEImage = class
  private
    FDosHeader : PImageDOSHeader;
    FNTHeader : PImageNTHeaders;
    FhModule: THandle;   // Handle to the module
    FSource : TMemoryStream;
    FisLoaded: boolean;  // Buffer with a module code
    FisException : Boolean; // Flags is a create exception

    function ReadImageHeaders : boolean;
    function isValidPEImage : boolean;
    function GetImportTable: Pointer;
    function RVAtoReal(RVA : Cardinal): pointer; overload;
    function RVAtoReal(RVA : Pointer): pointer; overload;

   public
     constructor Create(FileName : string; usedException : Boolean = False); overload;
     constructor Create(Stream : TMemoryStream; usedException : Boolean = False); overload;
     constructor Create(usedException : Boolean = False); overload;

     function LoadLibrary : boolean;

     function GetImportList : TImportsArray;     // Read Imports table from PE Image
     function GetImportsFromFile(FileName  :string) : TImportsArray;
     function GetDelayImportList : TImportsArray;

     {This function Hijack Function in ImportTable of given module with new
       yu must carry about all parameters and call conversions }
     function TryHijackFunction( aModule : THandle; LibName, FuncName : string;
            HijackFunction : Cardinal ) : Boolean ;

     property hModule : THandle read FhModule;
     property isLoaded : boolean read FisLoaded;
   end;

implementation

uses
  JclPeImage;

function ImageDirectoryEntryToData(Base: Pointer; MappedAsImage: ByteBool;
    DirectoryEntry: Word; var Size: ULONG): Pointer; stdcall; external 'imagehlp.dll'

function ImageNtHeader(Base : Pointer) : Pointer; stdcall; external 'dbghelp.dll'

function ImageRvaToVa(NtHeaders : Pointer; Base : Pointer; Rva : ULONG) : Pointer; stdcall; external 'dbghelp.dll';

{ THJPEImage }

constructor THJPEImage.Create(FileName : string; usedException : Boolean =
    False);
begin
  inherited Create;
  if FileExists(FileName) then
  begin
     FSource := TMemoryStream.Create;
     FSource.LoadFromFile(FileName);
     FhModule := Cardinal(Fsource.Memory);
  end;
  FisException := usedException;
end;

constructor THJPEImage.Create(Stream : TMemoryStream; usedException : Boolean =
    False);
begin
  inherited Create;
  if (Stream <> nil) and (Stream.Size > 0 ) then
  begin
     FSource := TMemoryStream.Create;
     FSource.CopyFrom(Stream, Stream.Size);
     FhModule := Cardinal(Fsource.Memory);
  end;
  FisException := usedException;
end;


constructor THJPEImage.Create(usedException : Boolean = False);
begin
   inherited Create;
   FSource := nil;
   FisException := usedException;
end;

function THJPEImage.GetDelayImportList: TImportsArray;
begin
  Setlength(Result, 0);
end;




function THJPEImage.GetImportList: TImportsArray;
var
  ImportDescriptor : PImageImportDescriptor;
  ThunkData: PImageThunkData;
  Name, LibraryName : PAnsiChar;
  ImportLib : PImportsLib;
  ImportFunc : PImportFunction;
  Size : DWORD;
begin
  SetLength(Result, 0);
  ImportDescriptor :=  ImageDirectoryEntryToData(FSource.Memory, BOOL(0),
    IMAGE_DIRECTORY_ENTRY_IMPORT, Size);

   While ImportDescriptor^.Name <> 0 do
   begin
      Setlength(Result, Length(Result) + 1);
      ImportLib := @Result[length(Result) - 1];
      LibraryName := RVAtoReal(ImportDescriptor^.Name);
      ImportLib.Name := LibraryName;
      Inc(ImportDescriptor);

   end; // end ImportDescriptor



end;

function THJPEImage.GetImportsFromFile(FileName: string): TImportsArray;
var
  i: Integer;
  Node, NodeChild : TTreeNode;
  Image : TJclPEImage;
  LibName : TStringList;
  J : Integer;
begin
  SetLength(Result, 0);
  LibName  := TStringList.Create;
  Image := TJclPEImage.Create(true);
  Image.FileName := FileName;
  if Image.IsBrokenFormat then exit;

  TreeView1.Items.BeginUpdate;
  with Image.ImportList do
  begin
    Image.ImportList.TryGetNamesForOrdinalImports;

    If Count = 0 then Continue;
    SetLength(Result, Count);

    For I:=0 to Count -1  do begin
      Result[I].Name := Items[I].Name;

      if Items[I].Count = 0 then Continue;
      SetLength(Result[I].imports, Items[I].Count);
      For J := 0 to Items[I].Count -1 do begin
        if Items[I].Items[J].IsByOrdinal then
        begin
          Result[I].imports[J].ID := Items[I].Items[J].Ordinal;
          Result[I].imports[J].Name := '';
        end
        else
        begin
          Result[I].imports[J].Name := Items[I].Items[J].Name;
          Result[I].imports[J].ID := 0;
        end;
      end;
    end;

  end;  // END with ImportList
  TreeView1.Items.EndUpdate;
end;


function THJPEImage.GetImportTable: Pointer;
begin
  Result := nil;
  with FNTHeader.OptionalHeader do
  begin
    if (DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress <> 0) and
          (DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].Size <> 0) then
      Result := RVAtoReal(DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);
  end;
end;

function THJPEImage.isValidPEImage: boolean;
begin
  Result := False;

  if not Assigned(FDOSHeader) then exit;
  if not Assigned(FNTHeader) then exit;
  if FDosHeader.e_magic <> IMAGE_DOS_SIGNATURE then exit;
  If FNTHeader.Signature  <> IMAGE_NT_SIGNATURE then exit;
  if FNTHeader.FileHeader.Machine <> IMAGE_FILE_MACHINE_I386 then exit;

  Result := True;
end;

function THJPEImage.LoadLibrary: boolean;
begin
  Result := False;
end;

function THJPEImage.ReadImageHeaders: boolean;
begin
  Result := false;
  if not Assigned(FSource) then exit;

  FDOSHeader := PImageDosHeader(FSource.Memory);
  FNTHeader := PImageNtHeaders(DWORD(FDOSHeader) + DWORD(FDOSHeader^._lfanew));

  if NOT isValidPEImage then exit;

  Result := True;
end;

function THJPEImage.RVAtoReal(RVA: Cardinal): pointer;
begin
  if Assigned(FSource) then
      Result := Pointer(hModule + RVA)
  else
      Result := nil;
end;

function THJPEImage.RVAtoReal(RVA: Pointer): pointer;
begin
  if Assigned(FSource) then
      Result := Pointer(hModule + Cardinal(RVA))
  else
      Result := nil;
end;

function THJPEImage.TryHijackFunction(aModule: THandle; LibName,
  FuncName: string; HijackFunction: Cardinal): Boolean;
begin
  Result := False;
  
end;

end.
