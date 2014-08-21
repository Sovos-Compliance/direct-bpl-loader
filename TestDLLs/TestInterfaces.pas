unit TestInterfaces;

interface

type
  ITestIntf = interface(IInterface)
  ['{07B94685-7E78-4021-BFFD-8C4FF4B4F9EB}']
    function Add(aValue1, aValue2: Integer): Integer;
    function Multiply(aValue1, aValue2: Integer): Integer;
    function Concatenate(const aValue1, aValue2: String): String;
  end;

implementation

end.
