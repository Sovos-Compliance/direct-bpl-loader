unit HijackGetProc;

interface
uses
  SysUtils,
  Windows,
  HijackImportProc;

Type

  TGetProcAddr = function (aHandle : THandle; aName : PAnsiChar) : Pointer; stdcall;

  THijackAPI = class

  end;

  function GetProcAddrX(aHandle : THandle; aName : PAnsiChar) : Pointer; stdcall;
  function HijackGetProcAddr(aDonor : TImportFuncArray): boolean;
  procedure RollBack;

var
  OriginalGetProcAddr :  TGetProcAddr;
  GetProcAddrThunk : Pointer;
  Donors :  TImportFuncArray;

implementation

procedure Rollback;
begin

end;

function RewritePointer(Thunk : Pointer; NewValue : PCardinal) : boolean;
var
  oldProtect : Cardinal;
  Writen : cardinal;
begin
  Result := false;
  try
    if VirtualProtect(Thunk, sizeOf(Cardinal), PAGE_READWRITE, oldProtect) then
    begin
      WriteProcessMemory(GetCurrentProcess, Thunk, NewValue,  SizeOf(Cardinal), Writen);
      VirtualProtect(Thunk, sizeOf(Cardinal), oldProtect, oldProtect);
      Result := true;
    end;
  except
    Result := False;
  end;
end;

function HijackGetProcAddr(aDonor : TImportFuncArray)  : boolean;
var
  aFunction : TImportFunction;
  I: Integer;
  hModule : THandle;
begin
  Result := false;
  // First save original GetProcAddress Pointer
  hModule := LoadLibrary('kernel32.dll');
  OriginalGetProcAddr := GetProcAddress(hModule, 'GetProcAddress');
  // Save old function thunks for RollBack
  SetLength(Donors, length(aDonor));
  for I := Low(aDonor) to High(aDonor) do
      Donors[I] := aDonor[I];
  // Replace with new Pointers
  try
    for I := Low(aDonor) to High(aDonor) do
    begin
        aFunction._Func := Cardinal(@GetProcAddrX);
        aFunction.LibName := 'kernel32.dll';
        aFunction.Addr := aDonor[I].Addr;
        if not HijackFunction(@aDonor[I], @aFunction) then
            raise Exception.Create('Error when Hijack GetProc');
    end;
     Result := true;
  except
     Result := false;
  end;
end;

function GetProcAddrX(aHandle : THandle; aName : PAnsiChar) : Pointer; stdcall;
begin
  MessageBox(0, 'Works great!!!!!', 'Yahoo ...', MB_OK + MB_ICONEXCLAMATION);
  if Assigned(OriginalGetProcAddr) then
    Result := OriginalGetProcAddr(aHandle, aName)
  else
    Result := nil;
end;

end.
