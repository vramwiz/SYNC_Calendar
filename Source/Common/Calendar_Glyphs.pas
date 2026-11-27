unit Calendar_Glyphs;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 数字とカレンダーに使う漢字を、内蔵の字形からポリゴンで描く。

interface

uses Calendar_Vector, Calendar_Settings;

// 紙面の指定位置に、Left を起点として文字列を加える。戻り値は次の描画位置。
function CalendarText(Art: TArt; const Value: string; Left, Top, Height: Single;
  Color: Cardinal; Style: TCalendarGlyphStyle = gsClassic): Single;
// 描画の余白込みの幅を返す。字形切り替え後も紙面の配置を共用できる。
function TextWidth(const Value: string; Height: Single): Single;
// 指定した紙面座標を中心として文字の三角形を追加する。
procedure CenterText(Art: TArt; const Value: string; X, Y, Height: Single;
  Color: Cardinal; Style: TCalendarGlyphStyle = gsClassic);

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

  // 角ゴシックと丸ゴシックで共有する、等幅の数字の骨格。
  GothicDigits: array['0'..'9'] of string = (
    '207091987929080120',
    '2351/5059',
    '01108091938416070999',
    '01108091937444/44749698891908',
    '700696/7079',
    '901004749598891908',
    '817020010819899895841405',
    '00905859',
    '207091937424030120/247495987929080524',
    '182979989180100104158594'
  );

function StrokeData(C: Char; Style: TCalendarGlyphStyle): string;
begin
  if CharInSet(C, ['0'..'9']) then
  begin
    if Style in [gsSquareGothic, gsRoundGothic] then Exit(GothicDigits[C]);
    if (Style = gsMincho) and (C = '1') then Exit('13326069');
    Exit(Digits[C]);
  end;
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

function RoundPath(const Path: array of TArtPoint; Amount: Single;
  var Rounded: array of TArtPoint): Integer;
var
  Corner, I: Integer;
  BeforeX, BeforeY, AfterX, AfterY, U, V: Single;
  A, B, C: TArtPoint;
begin
  Rounded[0] := Path[0];
  Result := 1;
  for Corner := 1 to High(Path) - 1 do
  begin
    A := Path[Corner - 1];
    B := Path[Corner];
    C := Path[Corner + 1];
    BeforeX := B.X + (A.X - B.X) * Amount;
    BeforeY := B.Y + (A.Y - B.Y) * Amount;
    AfterX := B.X + (C.X - B.X) * Amount;
    AfterY := B.Y + (C.Y - B.Y) * Amount;
    for I := 0 to 3 do
    begin
      U := I / 3;
      V := 1 - U;
      Rounded[Result] := Ink(V * V * BeforeX + 2 * U * V * B.X + U * U * AfterX,
        V * V * BeforeY + 2 * U * V * B.Y + U * U * AfterY, B.Color);
      Inc(Result);
    end;
  end;
  Rounded[Result] := Path[High(Path)];
  Inc(Result);
end;

procedure MinchoStroke(Art: TArt; const Path: array of TArtPoint; Weight: Single; C: Char);
var
  Widths: array[0..127] of Single;
  I: Integer;
  Prev, Tip, Next: TArtPoint;
  DX, DY, X, Y, Vertical, Thin: Single;
begin
  // 小さな漢字の横画は、日付の数字よりも線を残して潰れを抑える。
  Thin := 0.44;
  if CharInSet(C, ['0'..'9']) then Thin := 0.24;
  // 縦画を太く、横画を細くする。曲線では点ごとに傾きに沿って線幅を変える。
  for I := 0 to High(Path) do
  begin
    Prev := Path[Max(0, I - 1)];
    Next := Path[Min(High(Path), I + 1)];
    DX := Next.X - Prev.X;
    DY := Next.Y - Prev.Y;
    Vertical := Abs(DY) / Max(0.0001, Sqrt(DX * DX + DY * DY));
    Widths[I] := Thin + (1.17 - Thin) * Vertical * Vertical;
  end;
  Art.Stroke(Path, Weight, Slice(Widths, Length(Path)));

  // 横画の右端にうろこを置く。数字の直立した下端には台座を付ける。
  Tip := Path[High(Path)];
  Prev := Path[High(Path) - 1];
  X := Tip.X;
  Y := Tip.Y;
  DX := X - Prev.X;
  DY := Y - Prev.Y;
  if (DX > 0) and (Abs(DY) < DX * 0.25) then
    Art.Triangle(Ink(X - 0.82 * Weight, Y + 0.08 * Weight, Tip.Color),
      Ink(X - 0.29 * Weight, Y - 0.46 * Weight, Tip.Color),
      Ink(X + 0.10 * Weight, Y + 0.11 * Weight, Tip.Color));
  if CharInSet(C, ['1', '4']) and (DY > Abs(DX) * 3) then
  begin
    Art.Rect(X - Weight, Y - Weight * 0.065, X + Weight, Y + Weight * 0.12, Tip.Color);
    Art.Triangle(Ink(X - 0.97 * Weight, Y, Tip.Color),
      Ink(X - 0.41 * Weight, Y - 0.44 * Weight, Tip.Color), Ink(X, Y, Tip.Color));
    Art.Triangle(Ink(X + 0.97 * Weight, Y, Tip.Color),
      Ink(X + 0.41 * Weight, Y - 0.44 * Weight, Tip.Color), Ink(X, Y, Tip.Color));
  end;
end;

procedure DrawStroke(Art: TArt; const Path: array of TArtPoint; Weight, Height: Single;
  C: Char; Style: TCalendarGlyphStyle);
var
  Rounded: array[0..127] of TArtPoint;
  Roundness: Single;
  Count: Integer;
begin
  if Length(Path) < 2 then Exit;
  if Style = gsSquareGothic then
  begin
    Art.Stroke(Path, Weight, False);
    Exit;
  end;

  Roundness := 0;
  case Style of
    gsClassic:
      if (Height >= 60) and CharInSet(C, ['0', '2', '3', '5', '6', '8', '9']) then
        Roundness := 0.37;
    gsRoundGothic:
      if CharInSet(C, ['0'..'9']) then Roundness := 0.48
      else Roundness := 0.22;
    gsMincho:
      if CharInSet(C, ['0', '2', '3', '5', '6', '8', '9']) then Roundness := 0.43;
  end;
  if (Roundness > 0) and (Length(Path) >= 3) then
  begin
    Count := RoundPath(Path, Roundness, Rounded);
    if Style = gsMincho then MinchoStroke(Art, Slice(Rounded, Count), Weight, C)
    else Art.Stroke(Slice(Rounded, Count), Weight);
  end
  else if Style = gsMincho then MinchoStroke(Art, Path, Weight, C)
  else Art.Stroke(Path, Weight);
end;

function CalendarText(Art: TArt; const Value: string; Left, Top, Height: Single;
  Color: Cardinal; Style: TCalendarGlyphStyle): Single;
var
  C: Char;
  Data: string;
  Path: array[0..31] of TArtPoint;
  I, Count: Integer;
  Width, Weight, X, Y: Single;
  Digit: Boolean;
begin
  Result := Left;
  for C in Value do
  begin
    Data := StrokeData(C, Style);
    Width := Advance(C, Height);
    Digit := CharInSet(C, ['0'..'9']);
    Weight := Height * 0.064;
    if Digit then Weight := Height * 0.100;
    case Style of
      gsSquareGothic:
        if Digit then Weight := Height * 0.105 else Weight := Height * 0.072;
      gsRoundGothic:
        if Digit then Weight := Height * 0.096 else Weight := Height * 0.068;
      gsMincho:
        if Digit then Weight := Height * 0.104 else Weight := Height * 0.072;
    end;
    I := 1;
    Count := 0;
    while I < Length(Data) do
    begin
      if Data[I] = '/' then
      begin
        DrawStroke(Art, Slice(Path, Count), Weight, Height, C, Style);
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
    DrawStroke(Art, Slice(Path, Count), Weight, Height, C, Style);
    Result := Result + Width;
  end;
end;

procedure CenterText(Art: TArt; const Value: string; X, Y, Height: Single;
  Color: Cardinal; Style: TCalendarGlyphStyle);
begin
  CalendarText(Art, Value, X - TextWidth(Value, Height) * 0.5, Y - Height * 0.5, Height, Color, Style);
end;

end.
