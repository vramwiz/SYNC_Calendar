unit Calendar_Design;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// カレンダー各種の寸法と紙面のレイアウトを決める。

interface

uses Calendar_Settings, Calendar_Vector;

type
  TCalendarLayout = record
    Width, Height: Integer;
    Left, Top, Right, Bottom: Single;
  end;

function CalendarLayout(Kind: TCalendarKind): TCalendarLayout;
// 本体と留め具を別の面に追加する。紙面は AddPage から生成する。
procedure AddBackboard(Art: TArt; const L: TCalendarLayout; Paper: Cardinal);
procedure AddBinding(Art: TArt; const L: TCalendarLayout; Kind: TCalendarKind);
procedure AddPage(Art: TArt; const L: TCalendarLayout; const S: TCalendarSettings;
  Index: Integer; Back, Simple: Boolean);

implementation

uses System.SysUtils, System.DateUtils, Calendar_Glyphs, Calendar_Season;

const
  Weekdays = '日月火水木金土';
  Board = $293641;
  BoardRim = $5C6B75;
  RuleTint = $8997A3;

function CalendarLayout(Kind: TCalendarKind): TCalendarLayout;
begin
  case Kind of
    ckIllustrated: begin Result.Width := 646; Result.Height := 748; end;
    ckDay: begin Result.Width := 484; Result.Height := 596; end;
  else
    begin Result.Width := 692; Result.Height := 528; end;
  end;
  Result.Left := -Result.Width * 0.5 + 12;
  Result.Right := -Result.Left;
  Result.Top := -Result.Height * 0.5 + 40;
  Result.Bottom := Result.Height * 0.5 - 18;
end;

procedure AddBackboard(Art: TArt; const L: TCalendarLayout; Paper: Cardinal);
var
  I: Integer;
  Edge: Cardinal;
begin
  Art.Lift := -14;
  Art.RoundRect(L.Left - 12, L.Top - 40, L.Right + 12, L.Bottom + 18, 15, Board);
  Art.Lift := -12;
  Art.RoundRect(L.Left - 10, L.Top - 38, L.Right + 10, L.Bottom + 16, 13, BoardRim);
  Art.Lift := -10;
  Art.RoundRect(L.Left - 8, L.Top - 36, L.Right + 8, L.Bottom + 14, 11, Board);
  for I := 0 to 4 do
  begin
    Art.Lift := -8 + I * 1.24;
    Edge := MixColor(Paper, Board, 0.42 - I * 0.05);
    Art.RoundRect(L.Left, L.Top + 1, L.Right, L.Bottom + 10 - I * 1.7, 7, Edge);
    Art.Lift := Art.Lift + 0.12;
    Art.RoundRect(L.Left + 1, L.Top + 1, L.Right - 1, L.Bottom + 8.8 - I * 1.7,
      7, MixColor(Paper, Board, 0.16));
  end;
  Art.Lift := 0;
end;

procedure AddBinding(Art: TArt; const L: TCalendarLayout; Kind: TCalendarKind);
var
  I, Last: Integer;
  X, Gap: Single;
begin
  Art.Lift := 2;
  if Kind = ckDay then
  begin
    Art.RoundRect(-76, L.Top - 22, 76, L.Top + 8, 8, $152128);
    Art.Lift := 3.0;
    Art.RoundRect(-71, L.Top - 20, 71, L.Top + 5, 6, BoardRim);
    Art.Lift := 3.8;
    Art.Gradient(-65, L.Top - 16, 65, L.Top - 11, $D0D8D8, $7E8B92);
    Last := 1;
    Gap := 92;
  end
  else
  begin
    Last := 3;
    Gap := (L.Right - L.Left) * 0.212;
  end;
  for I := 0 to Last do
  begin
    X := (I - Last * 0.5) * Gap;
    Art.Lift := 1.3;
    Art.Oval(X, L.Top + 8, 8.5, 5.7, $27343E);
    Art.Lift := 4.0;
    Art.RoundRect(X - 4.8, L.Top - 24, X + 4.8, L.Top + 8, 4.0, $18252E);
    Art.Lift := 4.6;
    Art.RoundRect(X - 2.8, L.Top - 23, X + 2.8, L.Top + 5, 2.6, $8799A4);
    Art.Lift := 5.2;
    Art.Rect(X - 1.6, L.Top - 19, X - 0.1, L.Top + 1, $D4DEDE);
  end;
  Art.Lift := 0;
end;

procedure AddMonth(Art: TArt; const L: TCalendarLayout; const S: TCalendarSettings;
  Date: TDateTime; Y, M: Word; Simple: Boolean);
var
  Left, Right, Top, Header, Week, GridBottom, CellW, CellH, X, Mid, Size: Single;
  Edge, LabelColor: Cardinal;
  Col, Row, Slot, D, Offset: Integer;
  YearLabel: string;
begin
  Left := L.Left + 32;
  Right := L.Right - 32;
  Top := L.Top + 27;
  GridBottom := L.Bottom - 26;
  YearLabel := IntToStr(Y) + '年';
  Edge := MixColor(S.Colors[ccPaper], RuleTint, 0.38);
  if S.Kind = ckIllustrated then
  begin
    if not Simple then
    begin
      Art.Lift := 0.14;
      DrawSeason(Art, Y, M, Left, Top, Right - Left, 282);
    end;
    Top := Top + 298;
    Header := 56;
    Size := 24;
  end
  else
  begin
    Header := 88;
    Size := 33;
  end;

  Art.Lift := 0.18;
  X := CalendarText(Art, IntToStr(M), Left, Top, Header * 0.80, S.Colors[ccText]);
  CalendarText(Art, '月', X + 4, Top + Header * 0.32, Header * 0.38, S.Colors[ccText]);
  CalendarText(Art, YearLabel, Right - TextWidth(YearLabel, Header * 0.36),
    Top + Header * 0.29, Header * 0.36, S.Colors[ccText]);
  if Simple then Exit;

  Week := Top + Header;
  CellW := (Right - Left) / 7;
  CellH := (GridBottom - Week - 31) / 6;
  Art.Lift := 0.12;
  Art.Rect(Left, Week, Right, Week + 31, MixColor(S.Colors[ccPaper], RuleTint, 0.11));
  for Col := 0 to 6 do
  begin
    X := Left + Col * CellW;
    LabelColor := WeekdayColor(S, Col + 1);
    if Col in [0, 6] then
    begin
      Art.Lift := 0.14;
      Art.Rect(X, Week, X + CellW, Week + 31, MixColor(S.Colors[ccPaper], LabelColor, 0.085));
    end;
    Art.Lift := 0.22;
    CenterText(Art, Weekdays[Col + 1], X + CellW * 0.5, Week + 15.5, 20, LabelColor);
  end;
  Art.Lift := 0.16;
  for Row := 0 to 6 do
  begin
    X := Week + 31 + Row * CellH;
    Art.Rect(Left, X, Right, X + 0.95, Edge);
  end;
  for Col := 0 to 7 do
  begin
    X := Left + Col * CellW;
    Art.Rect(X, Week + 31, X + 0.78, GridBottom, Edge);
  end;
  Art.Lift := 0.23;
  Offset := DayOfWeek(Date) - 1;
  for D := 1 to DaysInAMonth(Y, M) do
  begin
    Slot := Offset + D - 1;
    Mid := Week + 31 + (Slot div 7 + 0.5) * CellH;
    CenterText(Art, IntToStr(D), Left + (Slot mod 7 + 0.5) * CellW, Mid, Size,
      DayColor(S, EncodeDate(Y, M, D)));
  end;
end;

procedure AddDay(Art: TArt; const L: TCalendarLayout; const S: TCalendarSettings;
  Date: TDateTime; Y, M, D: Word; Simple: Boolean);
var
  Text: string;
  Color, Rule: Cardinal;
begin
  Color := DayColor(S, Date);
  Rule := MixColor(S.Colors[ccPaper], RuleTint, 0.34);
  Art.Lift := 0.14;
  Art.Rect(L.Left + 31, L.Top + 98, L.Right - 31, L.Top + 99.5, Rule);
  Art.Rect(L.Left + 31, L.Bottom - 101, L.Right - 31, L.Bottom - 99.5, Rule);
  Art.Lift := 0.20;
  CenterText(Art, IntToStr(D), 0, (L.Top + L.Bottom) * 0.5 - 2, 277, Color, S.DayGlyph);
  if Simple then Exit;
  CenterText(Art, IntToStr(Y) + '年  ' + IntToStr(M) + '月', 0, L.Top + 61, 38,
    Color, S.DayGlyph);
  Text := Weekdays[DayOfWeek(Date)] + '曜日';
  CalendarText(Art, Text, L.Right - 34 - TextWidth(Text, 41), L.Bottom - 76, 41, Color, S.DayGlyph);
end;

procedure AddPage(Art: TArt; const L: TCalendarLayout; const S: TCalendarSettings;
  Index: Integer; Back, Simple: Boolean);
var
  Date: TDateTime;
  Y, M, D: Word;
  Color: Cardinal;
begin
  Color := S.Colors[ccPaper];
  if Back then Color := MixColor(Color, Board, 0.07);
  Art.Lift := 0;
  Art.RoundRect(L.Left, L.Top, L.Right, L.Bottom, 7, Color);
  Art.Lift := 0.08;
  Art.Gradient(L.Left + 7, L.Top + 1, L.Right - 7, L.Top + 17,
    MixColor(Color, Board, 0.09), Color);
  if Back then Exit;
  Date := PageDate(S.Kind, Index);
  DecodeDate(Date, Y, M, D);
  if S.Kind = ckDay then AddDay(Art, L, S, Date, Y, M, D, Simple)
  else AddMonth(Art, L, S, Date, Y, M, Simple);
end;

end.
