unit ReloadDLL;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DLLLoader;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
  MessageBox(Self.Handle, 'From Original', 'Start', MB_OK);
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  MessageBox( Self.Handle, 'Run Original' , 'Stop', MB_OK);
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  MyDll : TDLLFile;
  source : TMemoryStream;
begin
  source := TMemoryStream.Create;
  Source.LoadFromFile('testDll.dll');
  try
    MyDll := TDllFile.Create(Source); // Load DLL from stream
    // and then parsing there
    if MyDll.LoadFromStream then begin

    end;
  finally
     source.Free;
  end;
end;

end.
