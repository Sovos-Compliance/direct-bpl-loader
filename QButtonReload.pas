unit QButtonReload;

interface

uses
  SysUtils, Classes, QControls, QStdCtrls;

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

end.
