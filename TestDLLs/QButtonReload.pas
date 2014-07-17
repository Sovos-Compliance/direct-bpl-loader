unit QButtonReload;

interface

uses
  SysUtils, Classes, StdCtrls;

type
  TButtonReload = class(TButton)
  private
    { Private declarations }
  protected
    { Protected declarations }
  public
    { Public declarations }
  published
    { Published declarations }
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Convey', [TButtonReload]);
end;

initialization
  RegisterClass(TButtonReload); //VG 250614: Added line. It is needed so GetClass can find the class after the package is loaded

end.
