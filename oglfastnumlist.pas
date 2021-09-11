{ OGLFastNumList
   lightweighted numeric lists
   Copyright (c) 2021 Ilya Medvedkov   }

unit OGLFastNumList;

{$mode objfpc}
{$ifdef CPUX86_64}
{$asmMode intel}
{$endif}

interface

uses
  Classes, SysUtils, Variants;

type
  PNumByteArray = ^TNumByteArray;
  TNumByteArray = array[0..MaxInt] of Byte;

  { TFastBaseNumericList }

  generic TFastBaseNumericList<T> = class
  private
    FCount      : Integer;
    FCapacity   : Integer;
    FGrowthDelta: Integer;
    FSorted     : Boolean;

    FBaseList   : PNumByteArray;
    FItemSize   : Byte;
    FItemShift  : Byte;
    type
      TTypeList = array[0..MaxInt shr 4] of T;
      PTypeList = ^TTypeList;
    function Get(Index : Integer) : T;
    function GetList : PTypeList; inline;
    // methods for sorted lists
    function IndexOfSorted(const aValue : T) : Integer;
    function IndexOfLeftMost(const aValue : T) : Integer;
    function IndexOfRightMost(const aValue : T) : Integer;

    procedure Put(Index : Integer; const AValue : T);
    procedure SetSorted(AValue : Boolean);
    procedure Expand(growValue : Integer);
  protected
    procedure DeleteAll; virtual;
    procedure SetCapacity(NewCapacity: Integer); virtual;
    function  DoCompare(Item1, Item2 : Pointer) : Integer; virtual; abstract;
    procedure QSort(L : Integer; R : Integer); virtual;
    procedure DoSort; virtual;
  public
    constructor Create;
    destructor Destroy; override;

    property Items[Index: Integer]: T read Get write Put; default;
    property List : PTypeList read GetList;

    function DataSize: Integer; inline;
    procedure Flush;
    procedure Clear;

    procedure Add(const aValue : T);
    procedure AddSorted(const aValue : T);
    procedure AddEmptyValues(nbVals : Cardinal);
    function  IndexOf(const aValue : T) : Integer; virtual;
    procedure Insert(const aValue : T; aIndex : Integer);
    procedure Delete(Index: Integer); virtual;
    procedure DeleteItems(Index: Integer; nbVals: Cardinal); virtual;
    procedure Exchange(index1, index2: Integer);
    procedure Sort; inline;

    property Count: Integer read FCount;
    property Capacity: Integer read FCapacity write SetCapacity;

    property Sorted : Boolean read FSorted write SetSorted;
  end;

  { TFastByteList }

  TFastByteList = class(specialize TFastBaseNumericList<Byte>)
  protected
    function  DoCompare(Item1, Item2 : Pointer) : Integer; override;
  end;

  { TFastWordList }

  TFastWordList = class(specialize TFastBaseNumericList<Word>)
  protected
    function  DoCompare(Item1, Item2 : Pointer) : Integer; override;
  end;

  { TFastIntegerList }

  TFastIntegerList = class(specialize TFastBaseNumericList<Int32>)
  protected
    function  DoCompare(Item1, Item2 : Pointer) : Integer; override;
  end;

  { TFastCardinalList }

  TFastCardinalList = class(specialize TFastBaseNumericList<UInt32>)
  protected
    function  DoCompare(Item1, Item2 : Pointer) : Integer; override;
  end;

  { TFastInt64List }

  TFastInt64List = class(specialize TFastBaseNumericList<Int64>)
  protected
    function  DoCompare(Item1, Item2 : Pointer) : Integer; override;
  end;

  { TFastQWordList }

  TFastQWordList = class(specialize TFastBaseNumericList<UInt64>)
  protected
    function  DoCompare(Item1, Item2 : Pointer) : Integer; override;
  end;

  TKeyValuePair = packed record
    {$IFDEF CPU64}
    Key : QWord;
    {$ELSE}
    {$IFDEF CPU32}
    Key : DWord;
    {$endif}
    {$endif}
    case Byte of
    0: (Value: TObject);
    1: (PtrValue: Pointer);
    2: (Str : PChar);
    3: (WideStr : PWideChar);
    4: (PVar : PVariant);
  end;

  TKeyValuePairKind = (kvpkObject, kvpkPointer,
                       kvpkString, kvpkWideString,
                       kvpkVariant);

  { TFastKeyValuePairList }

  TFastKeyValuePairList = class(specialize TFastBaseNumericList<TKeyValuePair>)
  private
    FFreeValues : Boolean;
    FKeyValuePairKind : TKeyValuePairKind;
    procedure DisposeValue(Index : Integer); inline;
  protected
    procedure DeleteAll; override;
    function  DoCompare(Item1, Item2 : Pointer) : Integer; override;
  public
    constructor Create(aKind : TKeyValuePairKind;
                             aFreeValues : Boolean = true); overload;
    destructor Destroy; override;

    procedure Delete(Index: Integer); override;
    procedure DeleteItems(Index: Integer; nbVals: Cardinal); override;

    procedure AddObj(const aKey : QWord; aValue : TObject);
    procedure AddObjSorted(const aKey : QWord; aValue : TObject);
    procedure AddPtr(const aKey : QWord; aValue : Pointer);
    procedure AddPtrSorted(const aKey : QWord; aValue : Pointer);
    procedure AddStr(const aKey : QWord; aValue : PChar);
    procedure AddStrSorted(const aKey : QWord; aValue : PChar);
    procedure AddStr(const aKey : QWord; const aValue : String); overload;
    procedure AddStrSorted(const aKey : QWord; const aValue : String); overload;
    procedure AddWStr(const aKey : QWord; aValue : PWideChar);
    procedure AddWStrSorted(const aKey : QWord; aValue : PWideChar);
    procedure AddWStr(const aKey : QWord; const aValue : WideString); overload;
    procedure AddWStrSorted(const aKey : QWord; const aValue : WideString); overload;
    procedure AddVariant(const aKey : QWord; const aValue : Variant);
    procedure AddVariantSorted(const aKey : QWord; const aValue : Variant);

    property ValueKind : TKeyValuePairKind read FKeyValuePairKind
                                           write FKeyValuePairKind;
    property FreeValues : Boolean read FFreeValues write FFreeValues;
  end;


function KeyValuePair(const aKey : QWord; aValue : TObject) : TKeyValuePair; overload;
function KeyValuePair(const aKey : QWord; aValue : Pointer) : TKeyValuePair; overload;
function KeyValuePair(const aKey : QWord; aValue : PChar) : TKeyValuePair; overload;
function KeyValuePair(const aKey : QWord; aValue : PWideChar) : TKeyValuePair; overload;
function KeyValuePair(const aKey : QWord; const aValue : String) : TKeyValuePair; overload;
function KeyValuePairWS(const aKey : QWord; const aValue : WideString) : TKeyValuePair;
function KeyValuePairVar(const aKey : QWord; const aValue : Variant) : TKeyValuePair;


implementation

uses Math;

function KeyValuePair(const aKey : QWord; aValue : TObject) : TKeyValuePair;
begin
  Result.Key := aKey;
  Result.Value := aValue;
end;

function KeyValuePair(const aKey : QWord; aValue : Pointer) : TKeyValuePair;
begin
  Result.Key := aKey;
  Result.PtrValue := aValue;
end;

function KeyValuePair(const aKey : QWord; aValue : PChar) : TKeyValuePair;
var sl : Cardinal;
begin
  Result.Key := aKey;
  sl := strlen(aValue)+1;
  Result.Str := StrAlloc(sl);
  if sl > 0 then Move(aValue^, Result.Str^, sl) else
                 Result.Str[0] := #0;
end;

function KeyValuePair(const aKey : QWord; aValue : PWideChar
  ) : TKeyValuePair;
var sl : Cardinal;
begin
  Result.Key := aKey;
  sl := strlen(aValue)+1;
  Result.WideStr := WideStrAlloc(sl);
  if sl > 0 then Move(aValue^, Result.WideStr^, sl shl 1) else
                 Result.WideStr[0] := #0;
end;

function KeyValuePair(const aKey : QWord; const aValue : String
  ) : TKeyValuePair;
var sl : Cardinal;
begin
  Result.Key := aKey;
  sl := Length(aValue);
  Result.Str := StrAlloc(sl+1);
  if sl > 0 then Move(aValue[1], Result.Str^, sl);
  Result.Str[sl] := #0;
end;

function KeyValuePairWS(const aKey : QWord; const aValue : WideString
  ) : TKeyValuePair;
var sl : Cardinal;
begin
  Result.Key := aKey;
  sl := Length(aValue);
  Result.WideStr := WideStrAlloc(sl + 1);
  if sl > 0 then Move(aValue[1], Result.WideStr^, sl shl 1);
  Result.WideStr[sl] := #0;
end;

function KeyValuePairVar(const aKey : QWord; const aValue : Variant
  ) : TKeyValuePair;
begin
  Result.Key := aKey;
  Result.PVar := AllocMem(SizeOf(Variant));
  Result.PVar^ := aValue;
end;

{ TFastKeyValuePairList }

constructor TFastKeyValuePairList.Create(aKind : TKeyValuePairKind;
  aFreeValues : Boolean);
begin
  inherited Create;
  FFreeValues := aFreeValues;
  FKeyValuePairKind := aKind;
end;

procedure TFastKeyValuePairList.DisposeValue(Index : Integer);
begin
  case FKeyValuePairKind of
    kvpkObject :
        List^[Index].Value.Free;
    kvpkPointer :
        Freemem(List^[Index].PtrValue);
    kvpkString :
        StrDispose(List^[Index].Str);
    kvpkWideString :
        StrDispose(List^[Index].WideStr);
    kvpkVariant : begin
        VarClear(List^[Index].PVar^);
        Freemem(List^[Index].PVar);
    end;
  end;
end;

procedure TFastKeyValuePairList.DeleteAll;
var i : integer;
begin
  if FreeValues then
   for i := 0 to FCount-1 do
     DisposeValue(I);
  inherited DeleteAll;
end;

function TFastKeyValuePairList.DoCompare(Item1, Item2 : Pointer) : Integer;
{$ifdef CPUX86_64}
assembler;
asm
  mov rax, [Item1]
  cmp rax, [Item2]
  je @eq
  ja @gr
  jmp @le
  @eq:
  xor eax, eax
  jmp @@end
  @gr:
  mov eax, 1
  jmp @@end
  @le:
  mov eax, -1
  @@end:
{$else}
begin
  Result := Math.CompareValue(PT(Item1)^.Key, PT(Item2)^.Key);
{$endif}
end;

destructor TFastKeyValuePairList.Destroy;
begin
  Flush;
  inherited Destroy;
end;

procedure TFastKeyValuePairList.Delete(Index : Integer);
begin
  if FreeValues then
    DisposeValue(Index);
  inherited Delete(Index);
end;

procedure TFastKeyValuePairList.DeleteItems(Index : Integer; nbVals : Cardinal);
var i : integer;
begin
  if FreeValues then
    for i := Index to Index + nbVals - 1 do
      DisposeValue(i);
  inherited DeleteItems(Index, nbVals);
end;

procedure TFastKeyValuePairList.AddObj(const aKey : QWord; aValue : TObject);
begin
  Add(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddObjSorted(const aKey : QWord;
  aValue : TObject);
begin
  AddSorted(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddPtr(const aKey : QWord; aValue : Pointer);
begin
  Add(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddPtrSorted(const aKey : QWord;
  aValue : Pointer);
begin
  AddSorted(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddStr(const aKey : QWord; aValue : PChar);
begin
  Add(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddStrSorted(const aKey : QWord; aValue : PChar
  );
begin
  AddSorted(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddStr(const aKey : QWord; const aValue : String);
begin
  Add(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddStrSorted(const aKey : QWord;
  const aValue : String);
begin
  AddSorted(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddWStr(const aKey : QWord; aValue : PWideChar);
begin
  Add(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddWStrSorted(const aKey : QWord;
  aValue : PWideChar);
begin
  AddSorted(KeyValuePair(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddWStr(const aKey : QWord;
  const aValue : WideString);
begin
  Add(KeyValuePairWS(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddWStrSorted(const aKey : QWord;
  const aValue : WideString);
begin
  AddSorted(KeyValuePairWS(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddVariant(const aKey : QWord;
  const aValue : Variant);
begin
  Add(KeyValuePairVar(aKey, aValue));
end;

procedure TFastKeyValuePairList.AddVariantSorted(const aKey : QWord;
  const aValue : Variant);
begin
  AddSorted(KeyValuePairVar(aKey, aValue));
end;

{ TFastInt64List }

function TFastInt64List.DoCompare(Item1, Item2 : Pointer) : Integer;
{$ifdef CPUX86_64}
assembler;
asm
  mov rax, [Item1]
  cmp rax, [Item2]
  je @eq
  jg @gr
  jmp @le
  @eq:
  xor eax, eax
  jmp @@end
  @gr:
  mov eax, 1
  jmp @@end
  @le:
  mov eax, -1
  @@end:
{$else}
begin
  Result := Math.CompareValue(PT(Item1)^, PT(Item2)^);
{$endif}
end;

{ TFastQWordList }

function TFastQWordList.DoCompare(Item1, Item2 : Pointer) : Integer;
{$ifdef CPUX86_64}
assembler;
asm
  mov rax, [Item1]
  cmp rax, [Item2]
  je @eq
  ja @gr
  jmp @le
  @eq:
  xor eax, eax
  jmp @@end
  @gr:
  mov eax, 1
  jmp @@end
  @le:
  mov eax, -1
  @@end:
{$else}
begin
  Result := Math.CompareValue(PT(Item1)^, PT(Item2)^);
{$endif}
end;

{ TFastCardinalList }

function TFastCardinalList.DoCompare(Item1, Item2 : Pointer) : Integer;
{$ifdef CPUX86_64}
assembler;
asm
  mov eax, dword [Item1]
  cmp eax, dword [Item2]
  je @eq
  ja @gr
  jmp @le
  @eq:
  xor eax, eax
  jmp @@end
  @gr:
  mov eax, 1
  jmp @@end
  @le:
  mov eax, -1
  @@end:
{$else}
begin
  Result := Math.CompareValue(PT(Item1)^, PT(Item2)^);
{$endif}
end;

{ TFastIntegerList }

function TFastIntegerList.DoCompare(Item1, Item2 : Pointer) : Integer;
{$ifdef CPUX86_64}
assembler;
asm
  mov eax, dword [Item1]
  cmp eax, dword [Item2]
  je @eq
  jg @gr
  jmp @le
  @eq:
  xor eax, eax
  jmp @@end
  @gr:
  mov eax, 1
  jmp @@end
  @le:
  mov eax, -1
  @@end:
{$else}
begin
  Result := Math.CompareValue(PT(Item1)^, PT(Item2)^);
{$endif}
end;

{ TFastWordList }

function TFastWordList.DoCompare(Item1, Item2 : Pointer) : Integer;
{$ifdef CPUX86_64}
assembler;
asm
  mov ax, word [Item1]
  cmp ax, word [Item2]
  je @eq
  ja @gr
  jmp @le
  @eq:
  xor eax, eax
  jmp @@end
  @gr:
  mov eax, 1
  jmp @@end
  @le:
  mov eax, -1
  @@end:
{$else}
begin
  Result := Math.CompareValue(PT(Item1)^, PT(Item2)^);
{$endif}
end;

{ TFastByteList }

function TFastByteList.DoCompare(Item1, Item2 : Pointer) : Integer;
{$ifdef CPUX86_64}
assembler;
asm
  mov al, byte [Item1]
  cmp al, byte [Item2]
  je @eq
  ja @gr
  jmp @le
  @eq:
  xor eax, eax
  jmp @@end
  @gr:
  mov eax, 1
  jmp @@end
  @le:
  mov eax, -1
  @@end:
{$else}
begin
  Result := Math.CompareValue(PT(Item1)^, PT(Item2)^);
{$endif}
end;

{ TFastBaseNumericList }

destructor TFastBaseNumericList.Destroy;
begin
  Clear;
  inherited;
end;

function TFastBaseNumericList.GetList : PTypeList;
begin
  Result := PTypeList(FBaseList);
end;

function TFastBaseNumericList.Get(Index : Integer) : T;
begin
  Result := PTypeList(FBaseList)^[Index];
end;

procedure TFastBaseNumericList.Put(Index : Integer; const AValue : T);
begin
  PTypeList(FBaseList)^[Index] := AValue;
end;

procedure TFastBaseNumericList.SetSorted(AValue : Boolean);
begin
  if FSorted = AValue then Exit;
  if AValue then
    Sort
  else
    FSorted := AValue;
end;

procedure TFastBaseNumericList.Expand(growValue : Integer);
begin
  while growValue > 0 do
  begin
    SetCapacity(FCapacity + FGrowthDelta);
    Dec(growValue, FGrowthDelta);
    if FGrowthDelta < $FFFF then FGrowthDelta := FGrowthDelta shl 1;
  end;
end;

procedure TFastBaseNumericList.QSort(L : Integer; R : Integer);
var
  I, J, Pivot: Integer;
  PivotObj : Pointer;
  O1 : T;
begin
  repeat
    I := L;
    J := R;
    Pivot := (L + R) shr 1;
    PivotObj := @(List^[Pivot]);
    repeat
      while (I <> Pivot) and (DoCompare(@(List^[i]), PivotObj) < 0) do Inc(I);
      while (J <> Pivot) and (DoCompare(@(List^[j]), PivotObj) > 0) do Dec(J);
      if I <= J then
      begin
        if I < J then
        begin
          O1 := List^[J];
          List^[J] := List^[i];
          List^[i] := O1;
        end;
        if Pivot = I then
        begin
          Pivot := J;
          PivotObj := @(List^[Pivot]);
        end
        else if Pivot = J then
        begin
          Pivot := I;
          PivotObj := @(List^[Pivot]);
        end;
        Inc(I);
        Dec(j);
      end;
    until I > J;
    if L < J then
      QSort(L, J);
    L := I;
  until I >= R;
end;

procedure TFastBaseNumericList.DeleteAll;
begin
  FCount := 0;
end;

procedure TFastBaseNumericList.SetCapacity(NewCapacity : Integer);
begin
  if newCapacity <> FCapacity then
  begin
    ReallocMem(FBaseList, newCapacity shl FItemShift);
    FCapacity := newCapacity;
  end;
end;

procedure TFastBaseNumericList.DoSort;
begin
  QSort(0, FCount-1);
end;

function TFastBaseNumericList.DataSize: Integer;
begin
  Result := FCount shl FItemShift;
end;

constructor TFastBaseNumericList.Create;
var c : Byte;
begin
  FItemSize := SizeOf(T);
  c := FItemSize shr 1;
  FItemShift := 0;
  while c > 0 do
  begin
    c := c shr 1;
    Inc(FItemShift);
  end;
  FGrowthDelta := 16;
end;

procedure TFastBaseNumericList.Flush;
begin
  DeleteAll;
end;

procedure TFastBaseNumericList.Clear;
begin
  DeleteAll;
  SetCapacity(0);
end;

procedure TFastBaseNumericList.Add(const aValue : T);
begin
  if FCapacity <= FCount then Expand(1);
  List^[FCount] := aValue;
  Inc(FCount);
end;

procedure TFastBaseNumericList.AddSorted(const aValue : T);
var i : Integer;
begin
  if (not FSorted) or (FCount = 0) then begin
    Add(aValue);
    Exit;
  end;
  if FCapacity <= FCount then Expand(1);
  i := IndexOfRightMost(aValue);
  Insert(aValue, i + 1);
end;

procedure TFastBaseNumericList.AddEmptyValues(nbVals : Cardinal);
begin
  if FCapacity < (FCount + nbVals) then Expand(nbVals + FCount - FCapacity);
  Inc(FCount, nbVals);
end;

function TFastBaseNumericList.IndexOfLeftMost(const aValue : T) : Integer;
var R, m : Integer;
begin
  if (FCount = 0) or (DoCompare(@(List^[FCount-1]), @aValue) < 0) then Exit(FCount);
  Result := 0;
  R := FCount;
  while Result < R do
  begin
    m := (Result + R) shr 1;
    if DoCompare(@(List^[m]), @aValue) < 0  then
      Result := m + 1 else
      R := m;
  end;
end;

function TFastBaseNumericList.IndexOfRightMost(const aValue : T) : Integer;
var L, m : Integer;
begin
  if (FCount = 0) or (DoCompare(@(List^[0]), @aValue) > 0) then Exit(-1);
  L := 0;
  Result := FCount;
  while L < Result do
  begin
    m := (Result + L) shr 1;
    if DoCompare(@(List^[m]), @aValue) > 0 then
      Result := m else
      L := m + 1;
  end;
  Dec(Result);
end;

function TFastBaseNumericList.IndexOfSorted(const aValue : T) : Integer;
var R, L : Integer;
begin
  L := 0;
  R := FCount - 1;
  while L < R do
  begin
    Result := (L + R) shr 1;
    if DoCompare(@(List^[Result]), @aValue) < 0 then
      L := Result + 1 else
    if DoCompare(@(List^[Result]), @aValue) > 0 then
      R := Result - 1 else
      Exit;
  end;
  Result := -1;
end;

function TFastBaseNumericList.IndexOf(const aValue : T) : Integer;
var i : integer;
begin
  if FSorted and (FCount > 4) then
    Result := IndexOfSorted(aValue) else
  begin
    Result := -1;
    for i := 0 to FCount-1 do
      if DoCompare(@(List^[i]), @aValue) = 0 then Exit(i);
  end;
end;

procedure TFastBaseNumericList.Insert(const aValue : T; aIndex : Integer);
begin
  if FCount >= FCapacity then Expand(1);

  if aIndex < FCount then
    System.Move(List^[aIndex], List^[aIndex + 1],
      (FCount - aIndex) shl FItemShift);
  List^[aIndex] := aValue;
  Inc(FCount);
end;

procedure TFastBaseNumericList.Delete(Index: Integer);
begin
  Dec(FCount);
  if Index < FCount then
    System.Move(List^[Index + 1], List^[Index], (FCount - Index) shl FItemShift);
end;

procedure TFastBaseNumericList.DeleteItems(Index: Integer; nbVals: Cardinal);
begin
  if nbVals > 0 then
  begin
    if Index + Integer(nbVals) < FCount then
    begin
      System.Move(List^[Index + Integer(nbVals)], List^[Index],
                             (FCount - Index - Integer(nbVals)) shl FItemShift);
    end;
    Dec(FCount, nbVals);
  end;
end;

procedure TFastBaseNumericList.Exchange(index1, index2: Integer);
var m : T;
begin
  m := List^[index1];
  List^[index1] := List^[index2];
  List^[index2] := m;
end;

procedure TFastBaseNumericList.Sort;
begin
  if FCount > 1 then DoSort;
  FSorted := true;
end;

end.