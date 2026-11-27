unit Calendar_Glyphs;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 数字とカレンダーに使う漢字を、内蔵の字形からポリゴンで描く。

interface

uses Calendar_Vector;

// 紙面の指定位置に、Left を起点として文字列を加える。戻り値は次の描画位置。
function CalendarText(Art: TArt; const Value: string; Left, Top, Height: Single;
  Color: Cardinal): Single;
function TextWidth(const Value: string; Height: Single): Single;
procedure CenterText(Art: TArt; const Value: string; X, Y, Height: Single; Color: Cardinal);

implementation

uses System.SysUtils, System.Math;

const
  // 時計演出の座標ストローク方式を使い、日付用に字形と字幅を揃えた。
  Digits: array['0'..'9'] of string = (
    '30608193968869391806031130',
    '13326069/2999',
    '0221508092938465370999',
    '0221508092937454/5485969788692908',
    '70050696/7079',
    '901004346485969788692908',
    '81603011030618396988979584643405',
    '0090735539',
    '3060819283643413021130/34648596978869391807061534',
    '946434130211306081939688693918'
  );

function StrokeData(C: Char): string;
begin
  if CharInSet(C, ['0'..'9']) then Exit(Digits[C]);
  case C of
    '年': Result := '301102/2191/2383/2326/0797/5159';
    '月': Result := '2026170809/2080887959/2383/2585';
    '日': Result := '1119/118189/1484/1888';
    '火': Result := '5054472809/54667899/221304/827364';
    '水': Result := '50584939/0232241607/52647798/928464';
    '木': Result := '0393/5059/53351708/53658798';
    '金': Result := '503203/507293/2474/5458/1686/2738/7768/0999';
    '土': Result := '1484/5058/0999';
    '曜': Result := '0107/013137/0434/0737/406062/4362/709092/7392/534449/4494/6469/4696/4797/4999';
    else Result := '';
  end;
end;

function Advance(C: Char; Height: Single): Single;
begin
  if C = ' ' then Exit(Height * 0.30);
  if CharInSet(C, ['0'..'9']) then Exit(Height * 0.68);
  Result := Height * 1.06;
end;

function TextWidth(const Value: string; Height: Single): Single;
var
  C: Char;
begin
  Result := 0;
  for C in Value do Result := Result + Advance(C, Height);
end;

procedure DrawStroke(Art: TArt; const Path: array of TArtPoint; Weight: Single;
  RoundCorners: Boolean);
var
  Rounded: array[0..127] of TArtPoint;
  Corner, I, Count: Integer;
  BeforeX, BeforeY, AfterX, AfterY, U, V: Single;
  A, B, C: TArtPoint;
begin
  if not RoundCorners or (Length(Path) < 3) then
  begin
    Art.Stroke(Path, Weight);
    Exit;
  end;
  Rounded[0] := Path[0];
  Count := 1;
  for Corner := 1 to High(Path) - 1 do
  begin
    A := Path[Corner - 1];
    B := Path[Corner];
    C := Path[Corner + 1];
    BeforeX := B.X + (A.X - B.X) * 0.37;
    BeforeY := B.Y + (A.Y - B.Y) * 0.37;
    AfterX := B.X + (C.X - B.X) * 0.37;
    AfterY := B.Y + (C.Y - B.Y) * 0.37;
    for I := 0 to 3 do
    begin
      U := I / 3;
      V := 1 - U;
      Rounded[Count] := Ink(V * V * BeforeX + 2 * U * V * B.X + U * U * AfterX,
        V * V * BeforeY + 2 * U * V * B.Y + U * U * AfterY, B.Color);
      Inc(Count);
    end;
  end;
  Rounded[Count] := Path[High(Path)];
  Art.Stroke(Slice(Rounded, Count + 1), Weight);
end;

function CalendarText(Art: TArt; const Value: string; Left, Top, Height: Single;
  Color: Cardinal): Single;
var
  C: Char;
  Data: string;
  Path: array[0..31] of TArtPoint;
  I, Count: Integer;
  Width, Weight, X, Y: Single;
  RoundCorners: Boolean;
begin
  Result := Left;
  for C in Value do
  begin
    Data := StrokeData(C);
    Width := Advance(C, Height);
    Weight := Height * 0.064;
    if CharInSet(C, ['0'..'9']) then Weight := Height * 0.100;
    RoundCorners := (Height >= 60) and CharInSet(C, ['0', '2', '3', '5', '6', '8', '9']);
    I := 1;
    Count := 0;
    while I < Length(Data) do
    begin
      if Data[I] = '/' then
      begin
        DrawStroke(Art, Slice(Path, Count), Weight, RoundCorners);
        Count := 0;
        Inc(I);
        Continue;
      end;
      X := Result + Width * (0.13 + 0.74 * (Ord(Data[I]) - Ord('0')) / 9);
      Y := Top + Height * (0.08 + 0.84 * (Ord(Data[I + 1]) - Ord('0')) / 9);
      Path[Count] := Ink(X, Y, Color);
      Inc(Count);
      Inc(I, 2);
    end;
    DrawStroke(Art, Slice(Path, Count), Weight, RoundCorners);
    Result := Result + Width;
  end;
end;

procedure CenterText(Art: TArt; const Value: string; X, Y, Height: Single; Color: Cardinal);
begin
  CalendarText(Art, Value, X - TextWidth(Value, Height) * 0.5, Y - Height * 0.5, Height, Color);
end;

end.
