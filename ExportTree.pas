unit ExportTree;

interface

type
  PWordArray = ^TWordArray;
  TWordArray = array[0..(2147483647 div SIZEOF(WORD)) - 1] of WORD;
  PLongWordArray = ^TLongWordArray;
  TLongWordArray = array[0..(2147483647 div SIZEof(LONGWORD)) - 1] of LONGWORD;


  TExportTreeLink = POINTER;

  PExportTreeNode = ^TExportTreeNode;
  TExportTreeNode = record
    TheChar: CHAR;
    Link: TExportTreeLink;
    LinkExist: boolean;
    Prevoius, Next, Up, Down: PExportTreeNode;
  end;

  TExportTree = class
  private
    Root: PExportTreeNode;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Dump;
    function Add(functionName: string; Link: TExportTreeLink): boolean;
    function Delete(functionName: string): boolean;
    function Find(functionName: string; var Link: TExportTreeLink): boolean;
  end;

implementation
{helper function}
function CreateExportTreeNode(AChar: CHAR): PExportTreeNode;
begin
  GETMEM(Result, SIZEof(TExportTreeNode));
  Result^.TheChar := AChar;
  Result^.Link := nil;
  Result^.LinkExist := FALSE;
  Result^.Prevoius := nil;
  Result^.Next := nil;
  Result^.Up := nil;
  Result^.down := nil;
end;

procedure DestroyExportTreeNode(Node: PExportTreeNode);
begin
  if ASSIGNED(Node) then begin
    DestroyExportTreeNode(Node^.Next);
    DestroyExportTreeNode(Node^.down);
    FREEMEM(Node);
  end;
end;

function UpChar(C: char): char;
begin
  if (C >= 'a') and (C <= 'z')
    then Result := char(byte(C) - 32)
  else Result := C;
end;

{class TExportTree }
constructor TExportTree.Create;
begin
  inherited Create;
  Root := nil;
end;

destructor TExportTree.Destroy;
begin
  DestroyExportTreeNode(Root);
  inherited Destroy;
end;

procedure TExportTree.Dump;
var
  Ident: integer;
  procedure DumpNode(Node: PExportTreeNode);
  var
    SubNode: PExportTreeNode;
    IdentCounter, Identold: integer;
  begin
    for IdentCounter := 1 to Ident do write(' ');
    write(Node^.TheChar);
    Identold := Ident;
    SubNode := Node^.Next;
    while ASSIGNED(SubNode) do begin
      write(SubNode.TheChar);
      if not ASSIGNED(SubNode^.Next) then Break;
      INC(Ident);
      SubNode := SubNode^.Next;
    end;
    writeLN;
    INC(Ident);
    while ASSIGNED(SubNode) and (SubNode <> Node) do begin
      if ASSIGNED(SubNode^.down) then DumpNode(SubNode^.down);
      SubNode := SubNode^.Prevoius;
      DEC(Ident);
    end;
    Ident := Identold;
    if ASSIGNED(Node^.down) then DumpNode(Node^.down);
  end;
begin
  Ident := 0;
  DumpNode(Root);
end;

function TExportTree.Add(functionName: string; Link: TExportTreeLink): boolean;
var
  stringlength, Position, PositionCounter: integer;
  NewNode, LastNode, Node: PExportTreeNode;
  stringChar, NodeChar: CHAR;
begin
  Result := FALSE;
  stringlength := length(functionName);
  if stringlength > 0 then begin
    LastNode := nil;
    Node := Root;
    for Position := 1 to stringlength do begin
      stringChar := functionName[Position];
      if ASSIGNED(Node) then begin
        NodeChar := Node^.TheChar;
        if NodeChar = stringChar then begin
          LastNode := Node;
          Node := Node^.Next;
        end else begin
          while (NodeChar < stringChar) and ASSIGNED(Node^.down) do begin
            Node := Node^.down;
            NodeChar := Node^.TheChar;
          end;
          if NodeChar = stringChar then begin
            LastNode := Node;
            Node := Node^.Next;
          end else begin
            NewNode := CreateExportTreeNode(stringChar);
            if NodeChar < stringChar then begin
              NewNode^.down := Node^.down;
              NewNode^.Up := Node;
              if ASSIGNED(NewNode^.down) then begin
                NewNode^.down^.Up := NewNode;
              end;
              NewNode^.Prevoius := Node^.Prevoius;
              Node^.down := NewNode;
            end else if NodeChar > stringChar then begin
              NewNode^.down := Node;
              NewNode^.Up := Node^.Up;
              if ASSIGNED(NewNode^.Up) then begin
                NewNode^.Up^.down := NewNode;
              end;
              NewNode^.Prevoius := Node^.Prevoius;
              if not ASSIGNED(NewNode^.Up) then begin
                if ASSIGNED(NewNode^.Prevoius) then begin
                  NewNode^.Prevoius^.Next := NewNode;
                end else begin
                  Root := NewNode;
                end;
              end;
              Node^.Up := NewNode;
            end;
            LastNode := NewNode;
            Node := LastNode^.Next;
          end;
        end;
      end else begin
        for PositionCounter := Position to stringlength do begin
          NewNode := CreateExportTreeNode(functionName[PositionCounter]);
          if ASSIGNED(LastNode) then begin
            NewNode^.Prevoius := LastNode;
            LastNode^.Next := NewNode;
            LastNode := LastNode^.Next;
          end else begin
            if not ASSIGNED(Root) then begin
              Root := NewNode;
              LastNode := Root;
            end;
          end;
        end;
        Break;
      end;
    end;
    if ASSIGNED(LastNode) then begin
      if not LastNode^.LinkExist then begin
        LastNode^.Link := Link;
        LastNode^.LinkExist := TRUE;
        Result := TRUE;
      end;
    end;
  end;
end;

function TExportTree.Delete(functionName: string): boolean;
var stringlength, Position: integer;
  Node: PExportTreeNode;
  stringChar, NodeChar: CHAR;
begin
  Result := FALSE;
  stringlength := length(functionName);
  if stringlength > 0 then begin
    Node := Root;
    for Position := 1 to stringlength do begin
      stringChar := functionName[Position];
      if ASSIGNED(Node) then begin
        NodeChar := Node^.TheChar;
        while (NodeChar <> stringChar) and ASSIGNED(Node^.down) do begin
          Node := Node^.down;
          NodeChar := Node^.TheChar;
        end;
        if NodeChar = stringChar then begin
          if (Position = stringlength) and Node^.LinkExist then begin
            Node^.LinkExist := FALSE;
            Result := TRUE;
            Break;
          end;
          Node := Node^.Next;
        end;
      end else begin
        Break;
      end;
    end;
  end;
end;

function TExportTree.Find(functionName: string; var Link: TExportTreeLink): boolean;
var stringlength, Position: integer;
  Node: PExportTreeNode;
  stringChar, NodeChar: CHAR;
begin
  Result := FALSE;
  stringlength := length(functionName);
  if stringlength > 0 then begin
    Node := Root;
    for Position := 1 to stringlength do begin
      stringChar := functionName[Position];
      if ASSIGNED(Node) then begin
        NodeChar := Node^.TheChar;
        while (UpChar(NodeChar) <> UpChar(stringChar)) and ASSIGNED(Node^.down) do begin
          Node := Node^.down;
          NodeChar := Node^.TheChar;
        end;
        if UpChar(NodeChar) = UpChar(stringChar) then begin
          if (Position = stringlength) and Node^.LinkExist then begin
            Link := Node^.Link;
            Result := TRUE;
            Break;
          end;
          Node := Node^.Next;
        end;
      end else begin
        Break;
      end;
    end;
  end;
end;

end.
