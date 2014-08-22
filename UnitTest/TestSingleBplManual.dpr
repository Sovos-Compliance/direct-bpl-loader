program TestSingleBplManual;

uses
  Forms,
  TestSingleBplManualMain in 'TestSingleBplManualMain.pas' {frmMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
