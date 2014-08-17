unit TestClassA;

interface

uses
  SysUtils, Classes, StdCtrls;

type
  TTestClassA = class(TComponent)
  private
    { Private declarations }
  protected
    { Protected declarations }
  public
    function Add(aValue1, aValue2: Integer): Integer;
    { Public declarations }
  published
    { Published declarations }
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Convey', [TTestClassA]);
end;

function TTestClassA.Add(aValue1, aValue2: Integer): Integer;
begin
  Result := aValue1 + aValue2;
end;

initialization
  RegisterClass(TTestClassA);

end.
