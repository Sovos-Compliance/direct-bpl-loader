unit TestClassC;

interface

uses
  SysUtils, Classes, StdCtrls,
  TestClassB;

type
  TTestClassC = class(TTestClassB)
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
  RegisterComponents('Convey', [TTestClassC]);
end;

initialization
  RegisterClass(TTestClassC);

end.
