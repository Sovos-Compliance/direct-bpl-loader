unit TestClassC;

interface

uses
  Classes, 
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

implementation

initialization
  RegisterClass(TTestClassC);

end.
