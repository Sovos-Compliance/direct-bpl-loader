program PEImageView;

{%ToDo 'PEImageView.todo'}

uses
  Forms,
  uPEImageView in 'uPEImageView.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
