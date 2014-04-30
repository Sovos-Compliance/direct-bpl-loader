unit PEImageView;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls,
  PEImage;

type
  TForm2 = class(TForm)
    TreeView1: TTreeView;
    Label1: TLabel;
    Button1: TButton;
    OpenDialog1: TOpenDialog;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    Image : TPEImage;
  public
    { Public declarations }
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

procedure TForm2.Button1Click(Sender: TObject);
var
  i: Integer;
  ImportList : TImportsTable;
begin
  If OpenDialog1.Execute then
  begin
     Image := TPEImage.Create(OpenDialog1.FileName);
     ImportList := Image.GetImportList;

     for i := low(ImportList) to High(ImportList) do
     begin
        TreeView1.Items.Add(nil, ImportList[I].Name );
     end;
  end;
end;

end.
