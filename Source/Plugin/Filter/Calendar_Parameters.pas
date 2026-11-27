unit Calendar_Parameters;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// AviUtl2 が保存する項目を登録し、コールバック中だけ現在の値を読み取る。

interface

uses Calendar_Settings;

// DLL 所有の定義をフィルターテーブルへ登録する。
procedure RegisterCalendarParameters;
// SDK の項目値をコピーする。返す設定にホスト所有ポインターは含めない。
function ReadCalendarSettings: TCalendarSettings;

implementation

uses AviUtl2FilterTypes, PluginFilterTable;

const
  KindOptions: array[0..3] of TFILTER_ITEM_SELECT_ITEM = (
    (Name:'月めくり（全体表示型）'; Value:Ord(ckMonth)),
    (Name:'月めくり（イラスト型）'; Value:Ord(ckIllustrated)),
    (Name:'日めくり'; Value:Ord(ckDay)),
    (Name:nil; Value:0));
  EffectOptions: array[0..5] of TFILTER_ITEM_SELECT_ITEM = (
    (Name:'なし'; Value:Ord(ceNone)),
    (Name:'通常めくり'; Value:Ord(ceTurn)),
    (Name:'ペラペラめくり'; Value:Ord(ceFlutter)),
    (Name:'逆再生'; Value:Ord(ceReverse)),
    (Name:'ペラペラ逆再生'; Value:Ord(ceReverseFlutter)),
    (Name:nil; Value:0));
  // 選択値を画面上の順に割り当て、登録配列はポップアップの展開順に合わせる。
  GlyphOptions: array[0..4] of TFILTER_ITEM_SELECT_ITEM = (
    (Name:'手書き体'; Value:Ord(gsClassic)),
    (Name:'角ゴシック'; Value:Ord(gsSquareGothic)),
    (Name:'丸ゴシック'; Value:Ord(gsRoundGothic)),
    (Name:'明朝'; Value:Ord(gsMincho)),
    (Name:nil; Value:0));
  ColorNames: array[TCalendarColor] of PWideChar =
    ('通常文字色', '土曜日文字色', '日曜日・祝日文字色', '用紙色');
  DefaultColors: array[TCalendarColor] of Cardinal =
    ($000000, $0000FF, $FF0000, $FFFFFF);

var
  // 項目の実体は DLL が所有する。ホストから入力される文字列は描画中に読み取る。
  KindItem, EffectItem, GlyphItem: TFILTER_ITEM_SELECT;
  BaseItem, TargetItem: TFILTER_ITEM_STRING;
  HolidaysItem: TFILTER_ITEM_TEXT;
  TimeGroup, TimeEnd, ColorGroup, ColorEnd: TFILTER_ITEM_GROUP;
  DelayItem, DurationItem, VolumeItem: TFILTER_ITEM_TRACK;
  Colors: array[TCalendarColor] of TFILTER_ITEM_COLOR;

procedure RegisterCalendarParameters;
var
  C: TCalendarColor;
  RGB: Cardinal;
begin
  AddSelect(KindItem, 'カレンダー種類', Ord(ckMonth), @KindOptions[0]);
  AddSelect(GlyphItem, '日めくりの字形', Ord(gsMincho), @GlyphOptions[0]);
  AddString(BaseItem, '基準年月日', DefaultBaseDate);
  AddString(TargetItem, '目標年月日', DefaultTargetDate);
  AddSelect(EffectItem, '演出', Ord(ceNone), @EffectOptions[0]);

  AddGroup(TimeGroup, '時間設定', 1);
  AddTrack(DelayItem, '演出開始までの時間', 0, 0, MaxTiming, 0.01);
  AddTrack(DurationItem, '演出時間', 1, 0, MaxTiming, 0.01);
  AddGroup(TimeEnd, '', 0);

  AddText(HolidaysItem, '祝日', DefaultHolidays);
  AddGroup(ColorGroup, '色設定', 0);
  for C := Low(TCalendarColor) to High(TCalendarColor) do
  begin
    RGB := DefaultColors[C];
    AddColor(Colors[C], ColorNames[C], Byte(RGB), Byte(RGB shr 8), Byte(RGB shr 16), 0);
  end;
  AddGroup(ColorEnd, '', 0);
  AddTrack(VolumeItem, '音量', 50, 0, 100, 0.01);
end;

function ReadCalendarSettings: TCalendarSettings;
var
  C: TCalendarColor;
begin
  Result := Default(TCalendarSettings);
  if (KindItem.Value >= Ord(Low(TCalendarKind))) and
    (KindItem.Value <= Ord(High(TCalendarKind))) then
    Result.Kind := TCalendarKind(KindItem.Value);
  if (EffectItem.Value >= Ord(Low(TCalendarEffect))) and
    (EffectItem.Value <= Ord(High(TCalendarEffect))) then
    Result.Effect := TCalendarEffect(EffectItem.Value);

  if (GlyphItem.Value >= Ord(Low(TCalendarGlyphStyle))) and
    (GlyphItem.Value <= Ord(High(TCalendarGlyphStyle))) then
    Result.DayGlyph := TCalendarGlyphStyle(GlyphItem.Value);

  ReadPages(Result, BaseItem.Value, TargetItem.Value);
  Result.StartTime := FiniteRange(DelayItem.Value, 0, 0, MaxTiming);
  Result.Duration := FiniteRange(DurationItem.Value, 1, 0, MaxTiming);
  Result.Volume := FiniteRange(VolumeItem.Value, 50, 0, 100) / 100;
  Result.Holidays := ParseHolidays(HolidaysItem.Value);
  for C := Low(TCalendarColor) to High(TCalendarColor) do
    Result.Colors[C] := (Cardinal(Colors[C].R) shl 16) or
      (Cardinal(Colors[C].G) shl 8) or Colors[C].B;
end;

end.
