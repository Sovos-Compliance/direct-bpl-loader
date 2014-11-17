unit TestClassB;

interface

uses
  Classes, 
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

implementation

initialization
  RegisterClass(TTestClassB);

finalization
  UnRegisterClass(TTestClassB);

end.
