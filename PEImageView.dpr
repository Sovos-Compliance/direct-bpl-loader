program PEImageView;

uses
  Forms,
  uPEImageView in 'uPEImageView.pas' {Form2},
  mlBPLLoader in 'mlBPLLoader.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
