{***********************************************************
*  Class to load DLL and BPL module from stream            *
*  HiJack Function in main module (included GetProcAddress *
* And parsing resource string                              *
* ---------------------------------------------------------*
*  Created by Yuri Drigin : yuri.drigin@hotmail.com        *
*  based on JCL library ( PEImage.pas )                    *
************************************************************}
unit HJPEImage;

interface
uses
  Windows,
  Classes,
  SysUtils,
  JclPeImage,
  ImportsTable,
  ImageLoader;

const
  IMAGE_ORDINAL_FLAG32 = $80000000;
  IMAGE_ORDINAL_MASK32 = $7FFFFFFF;
  IMPORTED_NAME_OFFSET = $00000002;

Type

  EPEImageException = class(Exception);
  TGetProcAddr = function (aHandle : THandle; aName : PAnsiChar) : Pointer; stdcall;

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
  PHJPEImage = ^ THJPEImage;
  THJPEImage = class
  private
     FhModule: THandle;   // Handle to the module
     FSource : TMemoryStream;
     FisLoaded: boolean;  // Buffer with a module code
     FisException : Boolean; // Flags is a create exception
     FImage : TJclPEImage;
     FImportHook : TJclPeMapImgHooks;
     FisHijack: boolean;
     FImageLoader : THJImageLoader;

     function HasLibInImports(LibName: string): TJclPeImportLibItem;
     function isExistsImport(const LibName, FuncName: string; ImportArr : TImportsArray): Boolean;
     procedure SetisHijack(const Value: boolean);
     function GetFileName: TFileName;
     procedure SetFileName(const Value: TFileName);

   public
     constructor Create(FileName : string; usedException : Boolean = False); overload;
     constructor Create(Stream : TMemoryStream; usedException : Boolean = False); overload;
     constructor Create(usedException : Boolean = False); overload;
     destructor Destroy; override;

     function LoadLibraryFromStream : boolean;  overload;
     function LoadLibraryFromStream(Source : TMemoryStream) : Boolean; overload;

     function GetImportList : TImportsArray;     // Read Imports table from PE Image
     function GetImportsFromFile(FileName  :string) : TImportsArray;
     function GetDelayImportList : TImportsArray;
     function IsBrokenFormat: Boolean;
     //1 Return TStringList with names of all exported function in loaded module
     function GetExportList : TStringList;
     //1 Return to Addres of function in loaded module by Name
     function GetFuncAddress(name : string): Pointer;

     {This function Hijack Function in ImportTable of given module with new
       yu must carry about all parameters and call conversions }
     function TryHijackFunction(LibName, FuncName: string; NewFunction: Pointer):
         Boolean;
     {Get Original address of Hijacked function }
     function GetOldFunctionFromHijack(const Current : Pointer): Pointer;
     {Set back all Hijacked function}
     procedure RollBackHijackAll;
     {Set back hijacked function}
     procedure RollBackHijack( const Current : Pointer);

     property hModule : THandle read FhModule;  // handle to main module
     property isLoaded : boolean read FIsLoaded;   // Set true when load library from stream;

     property isHijack : boolean read FisHijack write SetisHijack;
     property Image : TJclPEImage read FImage;
     property FileName : TFileName read GetFileName write SetFileName;
   end;

implementation

var
  PHJImage : THJPEImage = nil;
  OldGetProc : TGetProcAddr = nil;

function NewGetProc(Handle : THandle; aName : PAnsiChar) : Pointer; stdcall;
var
   NewPointer : Pointer;
begin
   // First Get Original Address of Function
   Result := nil;
   If not Assigned(OldGetProc) then Exit;
   Result := OldGetProc(Handle, aName);

   if Result = nil then Exit;
   // Now try to find in Hijacked are
   if Assigned(PHJImage) then
        NewPointer := PHJImage.FImportHook.ItemFromOriginalAddress[Result].NewAddress;

   if NewPointer <> nil then
          Result := NewPointer;
end;


{ THJPEImage }

constructor THJPEImage.Create(FileName : string; usedException : Boolean =
    False);
begin
  Create(usedException);
  if FileExists(FileName) then
  begin
     FSource := TMemoryStream.Create;
     FSource.LoadFromFile(FileName);
  end;
end;

constructor THJPEImage.Create(Stream : TMemoryStream; usedException : Boolean =
    False);
begin
  Create(usedException);
  if (Stream <> nil) and (Stream.Size > 0 ) then
  begin
     FSource := TMemoryStream.Create;
     FSource.CopyFrom(Stream, Stream.Size);
     FImage.AttachLoadedModule( Cardinal(FSource.Memory));
  end;
end;

constructor THJPEImage.Create(usedException : Boolean = False);
begin
   inherited Create;
   FSource := nil;
   FisException := usedException;
   FhModule := GetModuleHandle(nil); // Set handle to then main module
   FImportHook := TJclPeMapImgHooks.Create;
   PHJImage := Self; // Set pointer to use in Hijacked GetProcAddress  Function
end;

destructor THJPEImage.Destroy;
begin
  inherited;
  FImportHook.UnhookAll;

end;

function THJPEImage.GetDelayImportList: TImportsArray;
begin
  Setlength(Result, 0);
end;


function THJPEImage.GetImportList: TImportsArray;
var
  I: Integer;
begin
  SetLength(Result, 0);

  If Not Image.StatusOK then Exit;

  SetLength(Result, Image.ImportList.Count);
  for I:= 0 to Image.ImportList.Count - 1 do
  begin
     Result[I].Name := Image.ImportList.Items[I].Name;
  end;

end;

function THJPEImage.GetImportsFromFile(FileName: string): TImportsArray;
var
  i: Integer;
  Image : TJclPEImage;
  J : Integer;
begin
  SetLength(Result, 0);
  Image := TJclPEImage.Create(true);
  Image.FileName := FileName;
  if Image.IsBrokenFormat then exit;

  with Image.ImportList do
  begin
    Image.ImportList.TryGetNamesForOrdinalImports;

    If Count = 0 then exit;
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
end;


function THJPEImage.GetOldFunctionFromHijack(const Current : POinter): Pointer;
begin
  Result := nil;
  if Assigned(FImportHook) then
    Result := FImportHook.ItemFromNewAddress[Current].OriginalAddress;
end;

function THJPEImage.HasLibInImports(LibName: string): TJclPeImportLibItem;
begin
  Result := nil ;

end;

function THJPEImage.isExistsImport(const LibName, FuncName: string; ImportArr :
    TImportsArray): Boolean;
var
  I: Integer;
  J: Integer;
begin
  Result := False;

  for I := Low(ImportArr) to High(ImportArr) do
    if ImportArr[I].Name = LibName then
    with ImportArr[I] do
      for J := Low(imports) to High(imports) do
        if imports[J].Name = FuncName then
        begin
            Result := True;
            Exit;
        end;
end;


function THJPEImage.LoadLibraryFromStream: boolean;
begin
  Result := False;
  if Assigned(FSource) then
  begin
     FImageLoader := THJImageLoader.Create(FSource);
     Result := FImageLoader.LoadFromStream;
     FisLoaded := Result;
  end;
end;

procedure THJPEImage.RollBackHijack(const Current: Pointer);
begin
  If Assigned(FImportHook) then
      FImportHook.UnhookByNewAddress(Current);
end;

procedure THJPEImage.RollBackHijackAll;
begin
  If Assigned(FImportHook) then
      FImportHook.UnhookAll;
  isHijack := False;
end;

function THJPEImage.TryHijackFunction(LibName,
  FuncName: string; NewFunction: Pointer): Boolean;
var
  OldFunction : Pointer;
begin
  Result := FImportHook.HookImport( Pointer(hModule), LibName, FuncName, NewFunction, OldFunction );
  if Result then
  begin
      isHijack := True;
      // Check is set a GetProcAddress Hook, If not set it
      if FImportHook.ItemFromNewAddress[@NewGetProc] = nil then
      begin
         FImportHook.HookImport(Pointer(hModule), 'kernel32.dll', 'GetProcAddress', @NewGetProc, OldFunction );
         OldGetProc := TGetProcAddr(OldFunction);
      end;
  end;
end;

procedure THJPEImage.SetisHijack(const Value: boolean);
begin
  FisHijack := Value;
end;

function THJPEImage.GetFileName: TFileName;
begin
  Result:= Image.FileName
end;

procedure THJPEImage.SetFileName(const Value: TFileName);
begin
  if Length(Value) > 0 then
    if FileExists(Value) then
        Image.FileName := Value;
end;

function THJPEImage.IsBrokenFormat: Boolean;
begin
  Result := False;
  if Assigned(FImage) then
      Result := FImage.IsBrokenFormat;
end;

function THJPEImage.GetExportList: TStringList;
begin
  Result := nil;
  if Assigned(FImageLoader) then
    if FisLoaded then
        Result := FImageLoader.GetExportList;  
end;

function THJPEImage.GetFuncAddress(name : string) : Pointer;
begin
  if Assigned( FImageLoader ) then
    Result := FImageLoader.GetFunctionAddress(Name)
  else
     Result := nil;
end;

function THJPEImage.LoadLibraryFromStream(Source: TMemoryStream): Boolean;
begin
  FSource.Clear;
  FSource.LoadFromStream(Source);
  Result := LoadLibraryFromStream;
end;

end.
