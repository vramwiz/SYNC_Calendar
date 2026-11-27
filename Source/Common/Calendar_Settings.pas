unit Calendar_Settings;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 日付・休日と、オブジェクトの時刻に対応する紙面と進行度を求める。

interface

uses System.SysUtils;

const
  DefaultBaseDate = '2026/12/31';
  DefaultTargetDate = '2027/1/1';
  DefaultHolidays = '1/1,2/11,2/23,4/29,5/3,5/4,5/5,8/11,11/3,11/23';
  MaxTiming = 86400;

type
  TCalendarKind = (ckMonth, ckIllustrated, ckDay);
  TCalendarEffect = (ceNone, ceTurn, ceFlutter, ceReverse, ceReverseFlutter);
  TCalendarGlyphStyle = (gsMincho, gsRoundGothic, gsSquareGothic, gsClassic);
  TCalendarColor = (ccText, ccSaturday, ccHoliday, ccPaper);
  THolidays = array[1..12] of set of 1..31;
  TCalendarSettings = record
    Kind: TCalendarKind;
    Effect: TCalendarEffect;
    DayGlyph: TCalendarGlyphStyle;
    BasePage, TargetPage: Integer;
    StartTime, Duration, Volume: Double;
    Holidays: THolidays;
    Colors: array[TCalendarColor] of Cardinal; // $RRGGBB
  end;

  // 映像・音声で共用する区間情報。進行方向と紙を動かす向きを独立して持つ。
  TCalendarSchedule = record
    First, Last, Turns: Integer;
    StartTime, Duration: Double;
    Fast, Reverse: Boolean;
  end;

  TCalendarFrame = record
    UnderPage, TurningPage: Integer;
    Progress: Double; // 0 = 綴じた紙、1 = 剥がれて消えた紙
    Turning, Simple: Boolean;
  end;

// 日付文字列を厳密に読み取り、基準の入力不正時は初期値、目標の入力不正時は基準を使う。
procedure ReadPages(var S: TCalendarSettings; BaseDate, TargetDate: PWideChar);
// 日めくりの日通算番号、または月めくりの月通算番号を暦日に戻す。
function PageDate(Kind: TCalendarKind; Index: Integer): TDateTime;
// 月日リストを年に依存しない集合へ変換する。空欄と不正な要素は読み飛ばす。
function ParseHolidays(Text: PWideChar): THolidays;
// 登録祝日と日曜・振替休日を土曜日より優先し、該当する文字色を返す。
function DayColor(const S: TCalendarSettings; Date: TDateTime): Cardinal;
// 日曜始まりの曜日番号（1～7）から、見出しに使う文字色を返す。
function WeekdayColor(const S: TCalendarSettings; Weekday: Integer): Cardinal;
// ホストから渡る数値を範囲に収める。NaN・無限大には初期値を使う。
function FiniteRange(Value, Fallback, Low, High: Double): Double;
// 設定から描画と音声で共用する有限のめくり回数と端点を作る。
function MakeSchedule(const S: TCalendarSettings): TCalendarSchedule;
// 相対時刻の秒数からフレームを決める。前の呼び出しの状態は使わない。
function CalendarFrame(const Schedule: TCalendarSchedule; Time: Double): TCalendarFrame;

implementation

uses System.Math;

const
  FirstCalendarDate = -693593; // EncodeDate(1, 1, 1) の Delphi 日付
  WeekdayColors: array[1..7] of TCalendarColor =
    (ccHoliday, ccText, ccText, ccText, ccText, ccText, ccSaturday);

function ReadNumber(const Value: string; var Pos: Integer; MinDigits,
  MaxDigits: Integer; out Number: Word): Boolean;
var
  Start: Integer;
begin
  Start := Pos;
  Number := 0;
  while (Pos <= Length(Value)) and CharInSet(Value[Pos], ['0'..'9']) do
  begin
    if Pos - Start = MaxDigits then Exit(False);
    Number := Number * 10 + Ord(Value[Pos]) - Ord('0');
    Inc(Pos);
  end;
  Result := Pos - Start >= MinDigits;
end;

function ReadSlash(const Value: string; var Pos: Integer): Boolean;
begin
  Result := (Pos <= Length(Value)) and (Value[Pos] = '/');
  if Result then Inc(Pos);
end;

function TryCalendarDate(const Input: string; out Date: TDateTime): Boolean;
var
  Value: string;
  Pos: Integer;
  Y, M, D: Word;
begin
  Value := Trim(Input);
  Pos := 1;
  Result := ReadNumber(Value, Pos, 4, 4, Y) and ReadSlash(Value, Pos) and
    ReadNumber(Value, Pos, 1, 2, M) and ReadSlash(Value, Pos) and
    ReadNumber(Value, Pos, 1, 2, D) and (Pos > Length(Value)) and
    TryEncodeDate(Y, M, D, Date);
end;

function PageIndex(Kind: TCalendarKind; Date: TDateTime): Integer;
var
  Y, M, D: Word;
begin
  if Kind = ckDay then Exit(Trunc(Date) - FirstCalendarDate);
  DecodeDate(Date, Y, M, D);
  Result := (Y - 1) * 12 + M - 1;
end;

procedure ReadPages(var S: TCalendarSettings; BaseDate, TargetDate: PWideChar);
var
  Date: TDateTime;
begin
  if not TryCalendarDate(string(BaseDate), Date) then
    Date := EncodeDate(2026, 12, 31);
  S.BasePage := PageIndex(S.Kind, Date);
  S.TargetPage := S.BasePage;
  if (S.Effect <> ceNone) and TryCalendarDate(string(TargetDate), Date) then
    S.TargetPage := PageIndex(S.Kind, Date);
end;

function PageDate(Kind: TCalendarKind; Index: Integer): TDateTime;
begin
  if Kind = ckDay then Exit(FirstCalendarDate + Index);
  Result := EncodeDate(Index div 12 + 1, Index mod 12 + 1, 1);
end;

function ParseHolidays(Text: PWideChar): THolidays;
var
  Start: PWideChar;
  Pos, Count: Integer;
  Value: string;
  M, D: Word;
  Date: TDateTime;

  function Separator(C: Char): Boolean;
  begin
    Result := (C <= ' ') or (C = ',') or (C = '、') or (C = '，') or (C = '　');
  end;

begin
  Result := Default(THolidays);
  if Text = nil then Exit;
  while Text^ <> #0 do
  begin
    if Separator(Text^) then
    begin
      Inc(Text);
      Continue;
    end;
    Start := Text;
    while not Separator(Text^) do Inc(Text);
    Count := Text - Start;
    if Count > 5 then Continue;
    SetString(Value, Start, Count);
    Pos := 1;
    // 2/29 は登録できる。実際にはその日が存在する年だけ使用する。
    if ReadNumber(Value, Pos, 1, 2, M) and ReadSlash(Value, Pos) and
      ReadNumber(Value, Pos, 1, 2, D) and (Pos > Length(Value)) and
      TryEncodeDate(2000, M, D, Date) then
      Include(Result[M], D);
  end;
end;

function WeekdayColor(const S: TCalendarSettings; Weekday: Integer): Cardinal;
begin
  Result := S.Colors[WeekdayColors[Weekday]];
end;

function DayColor(const S: TCalendarSettings; Date: TDateTime): Cardinal;
var
  Y, M, D: Word;
  Weekday: Integer;
begin
  Weekday := DayOfWeek(Date);
  DecodeDate(Date, Y, M, D);
  if (Weekday = 1) or (D in S.Holidays[M]) then Exit(S.Colors[ccHoliday]);
  if (Weekday = 2) and (Date > FirstCalendarDate) then
  begin
    DecodeDate(Date - 1, Y, M, D);
    if D in S.Holidays[M] then Exit(S.Colors[ccHoliday]);
  end;
  Result := WeekdayColor(S, Weekday);
end;

function FiniteRange(Value, Fallback, Low, High: Double): Double;
begin
  if IsNan(Value) or IsInfinite(Value) then Exit(Fallback);
  Result := EnsureRange(Value, Low, High);
end;

function MakeSchedule(const S: TCalendarSettings): TCalendarSchedule;
var
  Limit: Integer;
begin
  Result := Default(TCalendarSchedule);
  Result.First := S.BasePage;
  Result.Last := S.BasePage;
  Result.StartTime := S.StartTime;
  Result.Duration := S.Duration;
  if (S.Effect = ceNone) or (S.BasePage = S.TargetPage) then Exit;
  Result.Last := S.TargetPage;
  Result.Fast := S.Effect in [ceFlutter, ceReverseFlutter];
  Result.Reverse := S.Effect in [ceReverse, ceReverseFlutter];
  // 短時間に大量のページを指定しても、途中の日付を均等に選び、めくりが視認できる頻度に抑える。
  if Result.Fast then Limit := Min(720, Ceil(S.Duration * 18))
  else Limit := Min(240, Ceil(S.Duration * 5));
  Result.Turns := Min(Abs(S.TargetPage - S.BasePage), Max(1, Limit));
end;

function CalendarFrame(const Schedule: TCalendarSchedule; Time: Double): TCalendarFrame;
var
  SegmentTime: Double;
  Segment, FromPage, ToPage: Integer;
begin
  Result := Default(TCalendarFrame);
  Result.UnderPage := Schedule.First;
  if IsNan(Time) or (Schedule.Turns = 0) or (Time < Schedule.StartTime) then Exit;
  if (Schedule.Duration <= 0) or (Time >= Schedule.StartTime + Schedule.Duration) then
  begin
    Result.UnderPage := Schedule.Last;
    Exit;
  end;
  if Time = Schedule.StartTime then Exit;

  SegmentTime := (Time - Schedule.StartTime) / Schedule.Duration * Schedule.Turns;
  Segment := Min(Trunc(SegmentTime), Schedule.Turns - 1);
  FromPage := Schedule.First + Round(Int64(Schedule.Last - Schedule.First) *
    Segment / Schedule.Turns);
  ToPage := Schedule.First + Round(Int64(Schedule.Last - Schedule.First) *
    (Segment + 1) / Schedule.Turns);
  Result.Turning := True;
  Result.Progress := EnsureRange(SegmentTime - Segment, 0.0, 1.0);
  if Schedule.Reverse then
  begin
    Result.UnderPage := FromPage;
    Result.TurningPage := ToPage;
    Result.Progress := 1 - Result.Progress;
    Result.Simple := Schedule.Fast and (Segment + 1 < Schedule.Turns);
  end
  else
  begin
    Result.UnderPage := ToPage;
    Result.TurningPage := FromPage;
    Result.Simple := Schedule.Fast and (Segment > 0);
  end;
end;

end.
