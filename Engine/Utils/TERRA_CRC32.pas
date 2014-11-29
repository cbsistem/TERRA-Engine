Unit TERRA_CRC32;
{$I terra.inc}

Interface
Uses TERRA_IO;

Const
  TERRAPolynomial = $04c11db7;
  PNGPolynomial   = $EDB88320;

Type
  CRC32Table = Class
    Protected
      _Values:Array[0..255]Of Cardinal;

    Public
      Constructor Create(Polynomial:Cardinal);
  End;

Function GetCRC32(Source:Stream; Table:CRC32Table = Nil):Cardinal;Overload;
Function GetCRC32(Source:Stream; Start,Length:Integer; Table:CRC32Table = Nil):Cardinal;Overload;
Function GetCRC32(Source:AnsiString; Table:CRC32Table = Nil):Cardinal;Overload;
Function GetCRC32(Source:Pointer; Size:Integer; Table:CRC32Table = Nil):Cardinal;Overload;

Implementation
Uses TERRA_Log, TERRA_Utils;

Var
  _DefaultTable:CRC32Table;

Function GetCRC32(Source:Stream; Table:CRC32Table = Nil):Cardinal;
Begin
  Result := GetCRC32(Source, 0, Source.Size);
End;

Function GetCRC32(Source:Stream; Start,Length:Integer; Table:CRC32Table = Nil):Cardinal;
Const
  BufferSize=1024*32;
Var
  I:Integer;
  OP,Pos,Size:Integer;
  CRC:Cardinal;
  Buffer:Array[0..Pred(BufferSize)]Of Byte;
  BlockSize:Word;
Begin
  If Table = Nil Then
    Table := _DefaultTable;

  CRC := $FFFFFFFF;
  OP := Source.Position;
  Source.Seek(Start);
  Size := Length;
  Pos := 0;
  While (Pos<Size)Do
  Begin
    BlockSize:=IntMin(BufferSize,Source.Size-Source.Position);
    Source.Read(@Buffer[0],BlockSize);
    For I:=0 To Pred(BlockSize)Do
      CRC:=(CRC Shr 8) Xor Table._Values[(CRC Xor Buffer[I])And $FF];
    Inc(Pos,BlockSize);
  End;

  CRC := CRC Xor $FFFFFFFF;
  Source.Seek(OP);
  Result := CRC;
End;

Function GetCRC32(Source:Pointer; Size:Integer; Table:CRC32Table = Nil):Cardinal;
Var
 N:Byte;
 I:Integer;
 CRC:Cardinal;
Begin
  If Table = Nil Then
    Table := _DefaultTable;

  CRC:=$FFFFFFFF;
  For I:=1 To Size Do
  Begin
    N := PByte(Source)^;
    Inc(PByte(Source));
    CRC := (CRC Shr 8) Xor Table._Values[(CRC Xor N)And $FF];
  End;
  CRC := CRC Xor $FFFFFFFF;
  Result := CRC;
End;

Function GetCRC32(Source:AnsiString; Table:CRC32Table = Nil):Cardinal;
Var
 N:Byte;
 I:Integer;
 CRC:Cardinal;
Begin
  If Table = Nil Then
    Table := _DefaultTable;

  CRC := $FFFFFFFF;
  For I:=1 To Length(Source) Do
  Begin
    N := Byte(Source[I]);
    CRC := (CRC Shr 8) Xor Table._Values[(CRC Xor N)And $FF];
  End;
  CRC := CRC Xor $FFFFFFFF;
  Result := CRC;
End;

{ CRC32Table }

Constructor CRC32Table.Create(Polynomial: Cardinal);
Var
  I:Integer;
  Count:Integer;
  CRC:Cardinal;
Begin
  For I:=0 To 255 Do
  Begin
    CRC:=I;
    For Count:=8 DownTo 1 Do
    Begin
      If (CRC And 1)>0 Then
        CRC:=(CRC Shr 1) Xor Polynomial
      Else
        CRC:=CRC Shr 1;
   End;
    _Values[I] := CRC;
  End;
End;

Initialization
  Log(logDebug, 'CRC', 'Initializing');
  _DefaultTable := CRC32Table.Create(TERRAPolynomial);
Finalization
  _DefaultTable.Destroy();
End.
