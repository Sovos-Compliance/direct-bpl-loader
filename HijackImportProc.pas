unit HijackImportProc;

interface
uses
  SysUtils,
  Windows,
  JclWin32;

Type

  PImportFunction = ^TImportFunction;
  TImportFunction = packed record
    _Func : Cardinal;
    Addr : Pointer;
    LibName : string;
  end;

  TImportFuncArray = array of TImportFunction;

  EHJInvalidHandle = class (Exception);
  EHJReadHeader = class (Exception);


  function TryHijackFunction(LibraryName, FunctionName : string; NewFunctionAddr
      : Cardinal; hModule : THandle = 0): boolean;

  //1 Read DOS header of Image with given Hanle
  function ReadDosHeader(aHandle : THandle) : boolean;
  function ReadNTHeader : boolean;
  function ReadImportsTable : boolean;
  function ReadImportsArray : integer;
  function GetAddrOfDonor(LibName, FuncName :string; var ImportFunc :
      TImportFunction): boolean;
  function FindDonorThunk(const aFunction : PImportFunction; var aDonor :
      PImportFunction): boolean;
  function findAllDonorThunk(const aFunction : PImportFunction; var aDonor :
      TImportFuncArray): boolean;

  function HijackFunction(const OldFunction, NewFunction : PImportFunction) : boolean;

implementation



var
  DosHeader : PImageDOSHeader;
  NTHeader : PImageNTHeaders32;
  ImportTable : PImageDataDirectory;
  ImportsArray : array of TImportFunction;

function RVAtoReal(RVA : LONGWORD): pointer;
begin
  result := nil;

  If NTHeader = nil then exit;
  if RVA <=0 then Exit;

  result := Pointer(NTHeader.OptionalHeader.ImageBase + RVA);
end;

function ReadDosHeader(aHandle : THandle) : boolean;
begin
  result := false;
  DosHeader := nil;

  if aHandle = 0 then
      exit;

  if aHandle = INVALID_HANDLE_VALUE then
      exit;

  try
     DosHeader := Pointer(aHandle);
     if DosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then
     begin
        DosHeader := nil;
        exit;
     end;
  except
    on E : Exception do
        exit;
  end;

  result := true;
end;

function ReadNTHeader : boolean;
begin
  result := false;

  if DosHeader = nil then exit;

  try
    NTHeader := Pointer( Cardinal(DosHeader) + Cardinal(DosHeader^._lfanew));
    If (NTHeader.Signature <> IMAGE_NT_SIGNATURE) or
        (NTHeader.FileHeader.Machine <> IMAGE_FILE_MACHINE_I386)  then
    begin
        NTHeader := nil;
        exit;
    end;
  except
    NTHeader := nil;
    exit;
  end;

  result := true;
end;

function ReadImportsTable : boolean;
begin
  result := false;

  if NTHeader = nil then exit;

  with NTHeader.OptionalHeader do
  begin
    if (DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress <> 0) and
          (DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].Size <> 0) then
    begin
      ImportTable := RVAtoReal(DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);

      if ImportTable <> nil then
          result := true;
    end;
  end;
end;

function ReadImportsArray : integer;
var
  ImportDescriptor : PImageImportDescriptor;
  ImportCount: Integer;
  ThunkData: PImageThunkData32;

  LibraryName : PChar;
begin

  ImportCount := 0;
  Result := -1;
  // Set pointer to first Image Descriptor
  ImportDescriptor := Pointer(ImportTable);
  SetLength(ImportsArray, 0);

  while ImportDescriptor^.Name <> 0 do begin
      // Save Library Name
     LibraryName :=  RVAtoReal(ImportDescriptor^.Name);

     // Get Import Address Table (IAT)
     ThunkData := RVAtoReal(ImportDescriptor^.FirstThunk);

     while ThunkData.ForwarderString <> 0 do begin
          Inc(ImportCount);
          SetLength(ImportsArray, ImportCount);
          ImportsArray[ImportCount-1].LibName := LibraryName;
          ImportsArray[ImportCount-1]._Func := ThunkData.Function_;
          // TODO :  If not work need skip integer size
          ImportsArray[ImportCount-1].Addr := ThunkData;
          Inc(ThunkData);
     end;

     Inc(ImportDescriptor);
  end;

  result := Length(ImportsArray);
end;

function GetAddrOfDonor(LibName, FuncName  :string; var ImportFunc : TImportFunction) : boolean;
var
   LibHandle : THandle;
begin
   Result := false;

   LibHandle := LoadLibrary(PChar(LibName));

   if (LibHandle <> INVALID_HANDLE_VALUE) or (LibHandle <> 0) then
   begin
      ImportFunc._Func  := Cardinal(GetProcAddress(LibHandle, PChar(FuncName)));
      ImportFunc.LibName := LibName;

      if ImportFunc._Func <> 0 then
          Result := true; 
   end;

end;

function FindDonorThunk(const aFunction : PImportFunction; var aDonor :
    PImportFunction): boolean;
var
  I: Integer;
begin
  Result := False;

  for I := Low(ImportsArray)  to High(ImportsArray)  do
  begin
     aDonor := @ImportsArray[I];
     if aDonor._Func = aFunction._Func then
     begin
        Result := True;
        exit;
     end;
  end;
end;

function findAllDonorThunk(const aFunction : PImportFunction; var aDonor :
      TImportFuncArray): boolean;
var
  I: Integer;
begin
  Result := False;
  SetLength(aDonor, 0);
  for I := Low(ImportsArray)  to High(ImportsArray)  do
  begin
     if ImportsArray[I]._Func = aFunction._Func then
     begin
        SetLength(aDonor, length(aDonor) + 1);
        aDonor[length(aDonor) -1] := ImportsArray[I];
     end;
  end;

  if Length(aDonor) > 0 then
      Result := true;
end;

function HijackFunction(const OldFunction, NewFunction : PImportFunction) : boolean;
var
  OldProtect : Cardinal;
  ThunkData: PImageThunkData32;
  Writen : Cardinal;
begin
  Result := false;

  ThunkData := OldFunction.Addr;
  if VirtualProtect(ThunkData, sizeOf(Cardinal), PAGE_READWRITE, oldProtect) then
  try
    WriteProcessMemory(GetCurrentProcess, ThunkData, NewFunction, SizeOf(Cardinal), Writen);
    // InterlockedExchange(
    FlushInstructionCache(GetCurrentProcess, ThunkData, SizeOf(DWORD));
    Result := true;
  finally
    VirtualProtect(ThunkData, sizeOf(Cardinal), oldProtect, oldProtect);
  end;
end;

function TryHijackFunction(LibraryName, FunctionName : string;
      NewFunctionAddr : Cardinal;  hModule : THandle = 0) : boolean;
var
  aFunction : TImportFunction;
  aDonor : PImportFunction;

begin
  Result := False;
  if hModule = 0 then
    hModule := GetModuleHandle(nil);

  if length(LibraryName) = 0 then exit;
  if length(FunctionName) = 0 then exit;

  if ReadDosHeader(hModule) then
    if ReadNTHeader then
      if ReadImportsTable then
        if ReadImportsArray <> -1 then
         if GetAddrOfDonor(LibraryName, FunctionName, aFunction) then
            if FindDonorThunk(@aFunction, aDonor) then
            begin
               try
                 aFunction._Func := NewFunctionAddr;
                 aFunction.LibName := LibraryName;
                 aFunction.Addr := aDonor.Addr;
                 if HijackFunction(aDonor, @aFunction) then
                      Result := True;
               except
                 Result := false;
               end;
            end;

end;

end.
