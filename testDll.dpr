library testDll;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  SysUtils,
  Windows,
  Classes;

{$R *.res}

procedure Start (Sender : TObject);
begin
  MessageBox(0 , 'Run direct', 'Start', MB_OK);
end;

procedure Stop (Sender  : TObject);
begin
  MessageBox(0, 'Run direct', 'Stop', MB_OK);
end;


procedure DllMain(reason: integer) ;
begin
    case reason of
      DLL_PROCESS_ATTACH:
      begin
        // Start;
      end;
      DLL_PROCESS_DETACH:
      begin
        // Stop;
      end;
    end;
end;

exports
  Start, Stop;

begin
  DLLProc := @DllMain;
  DLLProc(DLL_PROCESS_ATTACH);
end.
