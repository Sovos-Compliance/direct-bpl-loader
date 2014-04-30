{Example of usage THJPEImage class}
unit uPEImageView;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls,
  HJPEImage, ImageLoader;

type
  TForm2 = class(TForm)
    TreeView1: TTreeView;
    Label1: TLabel;
    Button1: TButton;
    OpenDialog1: TOpenDialog;
    btnLoadHJPE: TButton;
    btnLoadSelf: TButton;
    btnCheckSelfImports: TButton;
    btnRoolback: TButton;
    lstExports: TListBox;
    lbl1: TLabel;
    btnGetFuncAddr: TButton;
    edtFuncAddr: TEdit;
    btnCall: TButton;
    mmo1: TMemo;
    procedure btnCallClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnCheckSelfImportsClick(Sender: TObject);
    procedure btnGetFuncAddrClick(Sender: TObject);
    procedure btnLoadHJPEClick(Sender: TObject);
    procedure btnLoadSelfClick(Sender: TObject);
    procedure btnRoolbackClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    HJImage : THJPEImage;

    procedure SetViewImportArray(const ImportArr: TImportsArray);
    { Private declarations }
  public
    { Public declarations }

    property PEImage : THJPEImage read HJImage;

  end;

  function MyMessage(wnd : HWND; lpText, lpCaption : PAnsiChar; uType : Cardinal) : Integer; stdcall;

  procedure Start(Sender : TObject); external 'testDll.Dll'; 

var
  Form2: TForm2;

implementation
{$R *.dfm}

type
  TMsgBox = function (wnd : HWND; lpText, lpCaption : PAnsiChar; uType : Cardinal) : Integer; stdcall;


{HiJack MessageBoxA function in main module}
procedure TForm2.btnCheckSelfImportsClick(Sender: TObject);
var
  MBFunc : TMsgBox;
  hModule : THandle;
begin
  // first call original MessageBoxA
  MessageBox(0, 'original' , 'test', MB_OK);
  // now try to HiJack function with our - see in this module
  // only one difference - in the title say : Yahooo !!! Works !!!
  if  HJImage.TryHijackFunction('user32.dll', 'MessageBoxA', @MyMessage) then
  begin
     // now call ne function
     MessageBox(0, 'original', 'test', MB_OK);
     // and now call Original MsgBox for compare
     hModule := LoadLibrary('user32.dll');
     MBFunc := GetProcAddress(hModule, 'MessageBoxA');
     if Assigned( MBFunc) then
        MBFunc(0, 'Hijacked GetProcAddress', 'test' , MB_OK);
  end;
end;

{Load module dll or bpl from memory stream and show all export function from it}
procedure TForm2.btnLoadHJPEClick(Sender: TObject);
var
  ImportArr : TImportsArray;
  ExportList : TStringList;
  I: Integer;
begin
  // select file
  if OpenDialog1.Execute then
  begin
     if Assigned(HJImage) then HJImage.Free;  // Clear previouse instance
     HJImage := THJPEImage.Create(OpenDialog1.FileName); // create new from file - we can create from stream
                                                         // or load module in memory late
     if not HJImage.LoadLibraryFromStream then Exit;
     // update ListBox
     lstExports.Items.BeginUpdate;
     lstExports.Items.Clear;
     ExportList := HJImage.GetExportList;
     for I := 0 to ExportList.Count - 1  do
       lstExports.Items.Add(ExportList[I]);
     lstExports.Items.EndUpdate;
  end;
end;

{Get All Import Functions of main module}
procedure TForm2.btnLoadSelfClick(Sender: TObject);
var
  ImportArr : TImportsArray;
  FileName : string;
begin
  // set module name to us
  FileName := GetModuleName( 0 );
  // read import data directory
  ImportArr := HJImage.GetImportsFromFile(FileName);
  // show in the TreeView
  SetViewImportArray(ImportArr);
end;

procedure TForm2.Button1Click(Sender: TObject);
var
  i: Integer;
  Node  : TTreeNode;
  J : Integer;
begin
  If OpenDialog1.Execute then
  begin
    HJImage := THJPEImage.Create(true);
    HJImage.FileName := OpenDialog1.FileName;
    if HJImage.IsBrokenFormat then exit;

    TreeView1.Items.BeginUpdate;
    with HJImage.Image.ImportList do
    begin

      TryGetNamesForOrdinalImports;

      For I:=0 to Count -1  do begin
        Node := TreeView1.Items.Add( nil,  Items[I].Name );
        For J := 0 to Items[I].Count -1 do begin
           TreeView1.Items.AddChild(Node, Items[I].Items[J].Name );
        end;
      end;

    end;  // END with ImportList
    TreeView1.Items.EndUpdate;

  end; // END DialogOpen
end;

{For replace original MessageBoxA from user32.ddl in main module}
function MyMessage(wnd: HWND; lpText, lpCaption: PAnsiChar;
  uType: Cardinal): Integer; stdcall;
var
   OldMessage : function (wnd : HWND; lpText, lpCaption : PAnsiChar; uType : Cardinal) : Integer; stdcall;
   old : Pointer;
begin
   Result := 0;
   // Get address of original function
   Old := Form2.PEImage.GetOldFunctionFromHijack( @MyMessage);
   OldMessage := old;
   if Assigned(OldMessage) then
      // Call original from user32.dll whit new parameters
     Result := OldMessage(wnd, lpText, 'Yahoo !!! Works!!!', uType);
end;

procedure TForm2.btnCallClick(Sender: TObject);
var
  MsgBox : TMsgBox;
  TestPointer : Pointer;
  Start : procedure (sender : TObject);
begin
  Start := HJImage.GetFuncAddress(
            lstExports.Items[ lstExports.itemIndex] );
  Start(Self);
end;

procedure TForm2.btnGetFuncAddrClick(Sender: TObject);
begin
   edtFuncAddr.Text := IntToStr(
          Cardinal(
              HJImage.GetFuncAddress( lstExports.Items[ lstExports.ItemIndex]
              ) ) );
end;

procedure TForm2.btnRoolbackClick(Sender: TObject);
begin
  HJImage.RollBackHijackAll;
  MessageBox(0, 'Roll Back', 'Test', MB_OK);
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  HJImage := THJPEImage.Create(true);
end;

procedure TForm2.SetViewImportArray(const ImportArr: TImportsArray);
var
  I: Integer;
  J: Integer;
  Node: TTreeNode;
begin

  TreeView1.Items.BeginUpdate;
  TreeView1.Items.Clear;

  for I := Low(ImportArr) to High(ImportArr) do
  begin
      Node := TreeView1.Items.Add(nil, ImportArr[I].Name);
      with ImportArr[I] do
      For J:= Low(imports) to High(imports) do
      begin
         TreeView1.Items.AddChild(Node, imports[J].Name);
      end;
  end;

  TreeView1.Items.EndUpdate;
end;

end.
