unit TestClassB;

interface

uses
  SysUtils, Classes, StdCtrls,
  TestClassA;

type
  TTestClassB = class(TTestClassA)
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
  RegisterComponents('Convey', [TTestClassB]);
end;

initialization
  RegisterClass(TTestClassB);

end.
