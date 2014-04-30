{ PImportTable - class to fork for IAT
  (import address table) in PEImage }
unit ImportsTable;

interface
uses
  Windows;
Type
  PIMAGE_IMPORT_BY_NAME = ^IMAGE_IMPORT_BY_NAME;
  {$EXTERNALSYM PIMAGE_IMPORT_BY_NAME}
  _IMAGE_IMPORT_BY_NAME = record
    Hint: Word;
    Name: array [0..0] of Char;
  end;
  {$EXTERNALSYM _IMAGE_IMPORT_BY_NAME}
  IMAGE_IMPORT_BY_NAME = _IMAGE_IMPORT_BY_NAME;
  {$EXTERNALSYM IMAGE_IMPORT_BY_NAME}
  TImageImportByName = IMAGE_IMPORT_BY_NAME;
  PImageImportByName = PIMAGE_IMPORT_BY_NAME;

  PIMAGE_THUNK_DATA32 = ^IMAGE_THUNK_DATA32;
  {$EXTERNALSYM PIMAGE_THUNK_DATA32}
  _IMAGE_THUNK_DATA32 = record
    case Integer of
      0: (ForwarderString: PBYTE);
      1: (_function: DWORD);
      2: (Ordinal: DWORD);
      3: (AddressOfData: PIMAGE_IMPORT_BY_NAME);
  end;
  {$EXTERNALSYM _IMAGE_THUNK_DATA32}
  IMAGE_THUNK_DATA32 = _IMAGE_THUNK_DATA32;
  {$EXTERNALSYM IMAGE_THUNK_DATA32}
  TImageThunkData32 = IMAGE_THUNK_DATA32;
  PImageThunkData32 = PIMAGE_THUNK_DATA32;
  PImageThunkData = PImageThunkData32;

  TIIDUnion = record
   case Integer of
      0: (Characteristics: DWORD);
      1: (OriginalFirstThunk: PIMAGE_THUNK_DATA32);
  end;

  PIMAGE_IMPORT_DESCRIPTOR = ^IMAGE_IMPORT_DESCRIPTOR;
  {$EXTERNALSYM PIMAGE_IMPORT_DESCRIPTOR}
  _IMAGE_IMPORT_DESCRIPTOR = record
    Union: TIIDUnion;
    TimeDateStamp: DWORD;
    ForwarderChain: DWORD;
    Name: DWORD;
    FirstThunk: PIMAGE_THUNK_DATA32;
  end;
  {$EXTERNALSYM _IMAGE_IMPORT_DESCRIPTOR}
  IMAGE_IMPORT_DESCRIPTOR = _IMAGE_IMPORT_DESCRIPTOR;
  {$EXTERNALSYM IMAGE_IMPORT_DESCRIPTOR}
  TImageImportDescriptor = IMAGE_IMPORT_DESCRIPTOR;
  PImageImportDescriptor = PIMAGE_IMPORT_DESCRIPTOR;

  PImportsTable = ^TImportsTable;

  TImportsTable = class(TObject)
  private
    FDescriptor : PImageImportDescriptor;
  public
    constructor Create(Descriptor : PImageImportDescriptor);
    function NextDescriptor : boolean;
  end;

implementation

{ TImportsTable }

constructor TImportsTable.Create(Descriptor: PImageImportDescriptor);
begin
  inherited Create;
  if (Descriptor <> nil) then
    FDescriptor := Descriptor;

end;

function TImportsTable.NextDescriptor: boolean;
begin
  Inc(FDescriptor);
  if FDescriptor.Name <> 0 then
      result := True
  else
      Result := False;
end;

end.
