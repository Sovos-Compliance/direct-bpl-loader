library TestDll;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

{$R 'TestResources.res' 'TestResources.rc'}
// The above RC file contains 3 test resources
//TESTDATA RCDATA TESTDATA.TXT  - 10 bytes
//TESTICON ICON TESTICON.ICO    - 10134 bytes, various sizes
//TESTBMP BITMAP TESTBMP.BMP    - 3112 bytes

uses
  SysUtils,
  Windows,
  Classes;

{$R *.res}

procedure Start;
begin
  MessageBox(0 , 'Run direct', 'Start', MB_OK);
end;

procedure Stop;
begin
  MessageBox(0 , 'Run direct', 'Stop', MB_OK);
end;

procedure TestMessage (Sender : TObject);
begin
  MessageBox(0 , 'TestMessage', 'TestMessage', MB_OK);
end;

function TestAdd(A, B: Integer): Integer;
begin
  Result := A + B;
end;


procedure DllMain(reason: integer) ;
begin
    case reason of
      DLL_PROCESS_ATTACH:
      begin
//         Start;
      end;
      DLL_PROCESS_DETACH:
      begin
//         Stop;
      end;
    end;
end;

exports
  TestMessage, TestAdd;

begin
  DLLProc := @DllMain;
  DLLProc(DLL_PROCESS_ATTACH);
end.
