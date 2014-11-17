unit TestClassA;

interface

uses
  Classes,
  TestInterfaces;

type
  TTestClassA = class(TInterfacedPersistent, ITestIntf)
  private
    { Private declarations }
  protected
    { Protected declarations }
  public
    function Add(aValue1, aValue2: Integer): Integer;
    function Multiply(aValue1, aValue2: Integer): Integer;
    function Concatenate(const aValue1, aValue2: String): String;
  end;

implementation

function TTestClassA.Add(aValue1, aValue2: Integer): Integer;
begin
  Result := aValue1 + aValue2;
end;

function TTestClassA.Multiply(aValue1, aValue2: Integer): Integer;
begin
  Result := aValue1 + aValue2;
end;

function TTestClassA.Concatenate(const aValue1, aValue2: String): String;
begin
  Result := aValue1 + aValue2;
end;

initialization
  RegisterClass(TTestClassA);

finalization
  UnRegisterClass(TTestClassA);

end.
