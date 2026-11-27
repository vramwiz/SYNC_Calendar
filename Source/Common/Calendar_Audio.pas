unit Calendar_Audio;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// めくり動作の進行度から紙の擦れ・剥離・はためきの PCM 波形を生成する。

interface

uses AviUtl2FilterTypes, Calendar_Settings;

// オブジェクト開始からのサンプル番号を使う。出力はホストの音声バッファへコピーする。
procedure DrawCalendarAudio(Audio: PFILTER_PROC_AUDIO; const S: TCalendarSettings);

implementation

uses System.Math;

function NoiseValue(Index: Integer; Seed: Cardinal): Double;
var
  H: Cardinal;
begin
  H := Cardinal(Index) xor Seed;
  H := H xor (H shr 16);
  H := Cardinal((UInt64(H) * $7FEB352D) and $FFFFFFFF);
  H := H xor (H shr 15);
  H := Cardinal((UInt64(H) * $846CA68B) and $FFFFFFFF);
  Result := (H xor (H shr 16)) * (2.0 / 4294967295.0) - 1;
end;

function Noise(Time, Frequency: Double; Seed: Cardinal): Double;
var
  Pos, F, A: Double;
  I: Integer;
begin
  Pos := Time * Frequency;
  I := Floor(Pos);
  F := Pos - I;
  A := NoiseValue(I, Seed);
  Result := A + (NoiseValue(I + 1, Seed) - A) * F * F * (3 - 2 * F);
end;

function Pulse(P, Center, Width: Double): Double;
var
  D: Double;
begin
  D := Max(0.0, 1 - Abs(P - Center) / Width);
  Result := D * D;
end;

function PaperSound(const F: TCalendarFrame; Period, Volume: Double;
  Fast: Boolean): Single;
var
  P, Time, Fade, Scratch, Flutter, Snap, Grains: Double;
  Seed: Cardinal;
begin
  P := F.Progress;
  // 動画のシークやバッファ分割に関係なく、同じ紙と進行度には同じ擦過音を使う。
  Time := P * Min(0.80, Period);
  Seed := Cardinal(F.TurningPage + 1) xor $CBFA7129;
  Fade := Min(1.0, Min(P, 1 - P) * 22);
  Grains := 0.56 + 0.44 * Noise(Time, 78, Seed xor $914ACDE9);
  Scratch := (Noise(Time, 6200, Seed) - 0.7 * Noise(Time, 1600, Seed)) *
    (0.22 * Pulse(P, 0.16, 0.14) + 0.28 * Pulse(P, 0.35, 0.15));
  Flutter := Noise(Time, 970, Seed xor $2B79F5AC) * Grains *
    (0.14 * Pulse(P, 0.43, 0.32) + 0.15 * Pulse(P, 0.65, 0.25));
  Snap := (0.44 * Noise(Time, 11900, Seed xor $5A43B2D1) +
    0.25 * Noise(Time, 390, Seed)) * Pulse(P, 0.60, 0.075);
  if Fast then Snap := Snap * 0.72;
  Result := EnsureRange((Scratch * Grains + Flutter + Snap) * Fade * Volume, -1.0, 1.0);
end;

procedure DrawCalendarAudio(Audio: PFILTER_PROC_AUDIO; const S: TCalendarSettings);
var
  Schedule: TCalendarSchedule;
  Frame: TCalendarFrame;
  Obj: POBJECT_INFO;
  Samples: TArray<Single>;
  I, Channel, SampleRate: Integer;
  Time, Period: Double;
begin
  Obj := Audio^.Object_;
  if (Obj^.SampleNum <= 0) or (Obj^.SampleNum > 1000000) or
    (Obj^.ChannelNum <= 0) or (Obj^.ChannelNum > 32) then Exit;
  SetLength(Samples, Obj^.SampleNum);
  Schedule := MakeSchedule(S);
  if (Audio^.Scene <> nil) and (Audio^.Scene^.SampleRate > 0) and
    (S.Volume > 0) and (Schedule.Turns > 0) and (Schedule.Duration > 0) then
  begin
    SampleRate := Audio^.Scene^.SampleRate;
    Period := Schedule.Duration / Schedule.Turns;
    for I := 0 to High(Samples) do
    begin
      Time := (Obj^.SampleIndex + I) / SampleRate;
      Frame := CalendarFrame(Schedule, Time);
      if Frame.Turning then Samples[I] := PaperSound(Frame, Period, S.Volume, Schedule.Fast);
    end;
  end;
  for Channel := 0 to Obj^.ChannelNum - 1 do
    Audio^.SetSampleData(@Samples[0], Channel);
end;

end.
