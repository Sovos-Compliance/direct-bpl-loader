program TestSingleBplManual;

uses
  Forms,
  TestSingleBplManualMain in 'TestSingleBplManualMain.pas' {frmMain},
  mlBaseLoader in '..\mlBaseLoader.pas',
  mlBPLLoader in '..\mlBPLLoader.pas',
  mlLibrary in '..\mlLibrary.pas',
  mlManagers in '..\mlManagers.pas',
  mlPEHeaders in '..\mlPEHeaders.pas',
  mlTypes in '..\mlTypes.pas',
  mlKOLDetours in '..\mlKOLDetours.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
