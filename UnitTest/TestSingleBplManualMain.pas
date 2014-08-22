unit TestSingleBplManualMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,
  TestConstants,
  mlLibraryManager,
  mlTypes;

type
  TfrmMain = class(TForm)
    memLog: TMemo;
    btnLoadPackage: TButton;
    procedure btnLoadPackageClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.btnLoadPackageClick(Sender: TObject);
var
  MemStream: TMemoryStream;
  LibHandle: TLibHandle;
  TestClass: TPersistentClass;
begin
  try
    MemStream := TMemoryStream.Create;
    try
      memLog.Lines.Add('Loading BPL file in the memory stream');
      MemStream.LoadFromFile(BPL_SINGLE_PATH);
      memLog.Lines.Add('Loading package from stream to memory');
      LibHandle := LoadPackageMem(MemStream, BPL_SINGLE_PATH);
      TestClass := GetClass(TEST_CLASS_NAME_A);
      if not Assigned(TestClass) then
        raise Exception.Create('Test class not found')
      else
        memLog.Lines.Add('Test class successfully loaded');  
      memLog.Lines.Add('Unloading package from memory');
      UnloadPackageMem(LibHandle);
    finally
      MemStream.Free;
    end;
  except on E: Exception do
    memLog.Lines.Add('Error: ' + E.Message);
  end;
end;

end.
