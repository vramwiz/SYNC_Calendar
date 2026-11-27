unit Calendar_Season;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 月ごとの風景をベクター図形で描く。年と月から同じ風景が再現される。

interface

uses Calendar_Vector;

// 指定された矩形の内側に風景を追加する。
procedure DrawSeason(Art: TArt; Year, Month: Word; X, Y, W, H: Single);

implementation

uses System.Math;

type
  TMotif = (msSnow, msBlossom, msGrass, msRain, msSea, msHarvest, msLeaves, msNight);
  TPalette = record
    Sky, Horizon, FarLand, Land, NearLand, Water, Sun, Detail: Cardinal;
    Motif: TMotif;
  end;

const
  Seasons: array[1..12] of TPalette = (
    (Sky:$789BBA; Horizon:$F5DED1; FarLand:$ABBED5; Land:$6E8FAA; NearLand:$D6E4EF; Water:$AEC8DA; Sun:$FCBC98; Detail:$FDFBFB; Motif:msSnow),
    (Sky:$A6B9D6; Horizon:$F9DFE4; FarLand:$B7AFC8; Land:$907FAD; NearLand:$5F577E; Water:$BEB0CC; Sun:$FFEDE7; Detail:$DC7392; Motif:msBlossom),
    (Sky:$8ABDCB; Horizon:$E5EDD2; FarLand:$A7BBAF; Land:$679487; NearLand:$407464; Water:$90BFBB; Sun:$FCF1C8; Detail:$FFE283; Motif:msGrass),
    (Sky:$94BBDA; Horizon:$F8DADB; FarLand:$B4B1C9; Land:$8D9AB7; NearLand:$5F7B98; Water:$ADBBD5; Sun:$FFF0D6; Detail:$F4AABB; Motif:msBlossom),
    (Sky:$6FB2CB; Horizon:$DDEDBE; FarLand:$9BBAAA; Land:$568E75; NearLand:$306859; Water:$71B5AB; Sun:$FFF0B8; Detail:$DAE992; Motif:msGrass),
    (Sky:$7085A7; Horizon:$DADDED; FarLand:$9696B5; Land:$656E99; NearLand:$4E626D; Water:$8095AC; Sun:$DBDFE7; Detail:$CFB1E9; Motif:msRain),
    (Sky:$429CCA; Horizon:$C7EBF1; FarLand:$83C2D6; Land:$4696A9; NearLand:$206D83; Water:$4AB0CC; Sun:$FFF9DB; Detail:$E4F4F4; Motif:msSea),
    (Sky:$508FC5; Horizon:$FFD9AF; FarLand:$8EAFCC; Land:$45879F; NearLand:$355C75; Water:$54A6C3; Sun:$FFD783; Detail:$FFE4B9; Motif:msSea),
    (Sky:$6597C0; Horizon:$FFE2AD; FarLand:$A2A8B3; Land:$917D84; NearLand:$696D59; Water:$9FB8BF; Sun:$FFF1B2; Detail:$E1AD59; Motif:msHarvest),
    (Sky:$6F749F; Horizon:$F9BA92; FarLand:$A98DA0; Land:$84667B; NearLand:$5B505F; Water:$AA8EA5; Sun:$FFE2A1; Detail:$F8C66A; Motif:msHarvest),
    (Sky:$84A3BD; Horizon:$F5C8A4; FarLand:$AB9EAD; Land:$967269; NearLand:$694B4A; Water:$AD999E; Sun:$FFF1C7; Detail:$DC7755; Motif:msLeaves),
    (Sky:$354C79; Horizon:$889EBD; FarLand:$7288A8; Land:$526F93; NearLand:$BACDE1; Water:$849FBC; Sun:$F6EED5; Detail:$EDF4FC; Motif:msNight)
  );

procedure DrawSeason(Art: TArt; Year, Month: Word; X, Y, W, H: Single);
var
  P: TPalette;
  I, J: Integer;
  U, V, Size, SunX, SunY, Edge, Lift: Single;
  Seed: Integer;

  function XAt(U: Single): Single;
  begin
    Result := X + W * U;
  end;

  function YAt(V: Single): Single;
  begin
    Result := Y + H * V;
  end;

  function RandomUnit: Single;
  begin
    Seed := (Int64(Seed) * 48271) mod 65521;
    Result := Seed / 65521;
  end;

  procedure Dot(U, V, RadiusX, RadiusY: Single; Color: Cardinal; Sides: Integer = 12);
  begin
    Art.Oval(XAt(U), YAt(V), W * RadiusX, H * RadiusY, Color, Sides);
  end;

  procedure Line(X1, Y1, X2, Y2, Width: Single; Color: Cardinal);
  begin
    Art.Stroke([Ink(XAt(X1), YAt(Y1), Color), Ink(XAt(X2), YAt(Y2), Color)],
      Width * H, False);
  end;

  procedure Hills(const Skyline: array of Single; Bottom: Single; Color: Cardinal);
  var
    I: Integer;
    Left, Right: Single;
  begin
    for I := 1 to High(Skyline) do
    begin
      Left := XAt((I - 1) / High(Skyline));
      Right := XAt(I / High(Skyline));
      Art.Polygon([Ink(Left, YAt(Skyline[I - 1]), Color),
        Ink(Right, YAt(Skyline[I]), Color), Ink(Right, YAt(Bottom), Color),
        Ink(Left, YAt(Bottom), Color)]);
    end;
  end;

begin
  P := Seasons[Month];
  Lift := Art.Lift;
  Seed := 1 + (Year * 173 + Month * 2707) mod 65520;
  Art.Gradient(X, Y, X + W, Y + H, P.Sky, P.Horizon);
  Art.Lift := Lift + 0.07;
  SunX := 0.69 + (RandomUnit - 0.5) * 0.22;
  SunY := 0.24 + (RandomUnit - 0.5) * 0.14;
  Size := 0.076;
  if Month in [8, 10, 12] then Size := 0.102;
  Dot(SunX, SunY, Size * H / W * 1.45, Size * 1.45, MixColor(P.Sky, P.Sun, 0.40), 30);
  Art.Lift := Lift + 0.13;
  Dot(SunX, SunY, Size * H / W, Size, P.Sun, 32);

  Art.Lift := Lift + 0.19;
  for I := 0 to 7 do
  begin
    U := 0.05 + RandomUnit * 0.82;
    V := 0.12 + RandomUnit * 0.27;
    if Abs(U - SunX) < 0.13 then Continue;
    Size := 0.045 + RandomUnit * 0.08;
    Line(U, V, U + Size, V, 0.003, MixColor(P.Sky, P.Sun, 0.48));
  end;
  Art.Lift := Lift + 0.26;
  Hills([0.62, 0.55, 0.39, 0.54, 0.48, 0.33, 0.53, 0.58, 0.45, 0.53, 0.60], 0.76, P.FarLand);
  if P.Motif in [msSnow, msNight] then
  begin
    Art.Lift := Lift + 0.30;
    Art.Polygon([Ink(XAt(0.43), YAt(0.435), P.Detail), Ink(XAt(0.50), YAt(0.33), P.Detail),
      Ink(XAt(0.564), YAt(0.458), P.Detail), Ink(XAt(0.52), YAt(0.435), P.Detail),
      Ink(XAt(0.492), YAt(0.423), P.Detail)]);
  end;

  Art.Lift := Lift + 0.37;
  Hills([0.52, 0.49, 0.55, 0.59, 0.63, 0.60, 0.62, 0.57, 0.52, 0.56, 0.64], 0.79, P.Land);
  Art.Lift := Lift + 0.43;
  Art.Gradient(X, YAt(0.655), X + W, Y + H, P.Water, MixColor(P.Water, P.Horizon, 0.22));
  Art.Lift := Lift + 0.48;
  for I := 0 to 22 do
  begin
    V := 0.675 + RandomUnit * 0.28;
    U := 0.04 + RandomUnit * 0.90;
    Size := 0.009 + RandomUnit * (V - 0.62) * 0.19;
    Line(U, V, Min(0.99, U + Size), V, 0.003 + (V - 0.66) * 0.012,
      MixColor(P.Water, P.Sun, 0.32 + 0.24 * RandomUnit));
  end;
  Art.Lift := Lift + 0.54;
  if P.Motif <> msSea then
    Hills([0.82, 0.85, 0.89, 0.94, 0.97, 0.98, 0.96, 0.91, 0.85, 0.82, 0.78], 1, P.NearLand);

  Art.Lift := Lift + 0.60;
  case P.Motif of
    msSnow, msNight:
      for I := 0 to 53 do
      begin
        U := 0.02 + RandomUnit * 0.96;
        V := 0.03 + RandomUnit * 0.90;
        Size := 0.002 + RandomUnit * 0.006;
        Dot(U, V, Size * H / W, Size, MixColor(P.Detail, P.Sky, 0.16 + RandomUnit * 0.39), 7);
      end;
    msBlossom, msLeaves:
      begin
        Line(0.008, 0.34, 0.31, 0.20, 0.021, P.NearLand);
        Line(0.11, 0.29, 0.24, 0.11, 0.010, P.NearLand);
        Line(0.16, 0.27, 0.30, 0.32, 0.009, P.NearLand);
        Art.Lift := Lift + 0.68;
        for I := 0 to 26 do
        begin
          U := 0.042 + RandomUnit * 0.278;
          V := 0.27 - 0.38 * U + (RandomUnit - 0.5) * 0.28;
          Size := 0.012 + RandomUnit * 0.021;
          for J := 0 to 4 do
            Dot(U + Cos(2 * Pi * J / 5) * Size * H / W, V + Sin(2 * Pi * J / 5) * Size,
              Size * H / W, Size * 0.74, MixColor(P.Detail, P.Sun, RandomUnit * 0.50), 7);
        end;
        for I := 0 to 13 do
        begin
          U := 0.20 + RandomUnit * 0.70;
          V := 0.36 + RandomUnit * 0.52;
          Dot(U, V, 0.005, 0.009, P.Detail, 6);
        end;
      end;
    msGrass, msHarvest:
      for I := 0 to 28 do
      begin
        U := 0.02 + RandomUnit * 0.30;
        if Odd(I) then U := 1 - U;
        V := 0.90 - RandomUnit * 0.06;
        Edge := U + (RandomUnit - 0.5) * 0.035;
        Line(U, 0.993, Edge, V, 0.006, MixColor(P.NearLand, P.Detail, 0.42));
        Dot(Edge, V, 0.005, 0.016, MixColor(P.Detail, P.Sun, RandomUnit * 0.4), 8);
      end;
    msRain:
      for I := 0 to 53 do
      begin
        U := 0.035 + RandomUnit * 0.94;
        V := 0.04 + RandomUnit * 0.87;
        Line(U, V, U - 0.014, V + 0.036, 0.004, MixColor(P.Detail, P.Sky, 0.5));
      end;
    msSea:
      begin
        U := 0.22 + RandomUnit * 0.17;
        V := 0.80;
        Art.Polygon([Ink(XAt(U - 0.04), YAt(V), P.NearLand), Ink(XAt(U + 0.04), YAt(V), P.NearLand),
          Ink(XAt(U + 0.026), YAt(V + 0.023), P.NearLand), Ink(XAt(U - 0.027), YAt(V + 0.023), P.NearLand)]);
        Art.Polygon([Ink(XAt(U), YAt(V - 0.19), P.Sun), Ink(XAt(U), YAt(V - 0.012), P.Sun),
          Ink(XAt(U - 0.031), YAt(V - 0.012), P.Detail)]);
        Art.Polygon([Ink(XAt(U + 0.007), YAt(V - 0.152), P.Detail), Ink(XAt(U + 0.032), YAt(V - 0.012), P.Sun),
          Ink(XAt(U + 0.007), YAt(V - 0.012), P.Sun)]);
      end;
  end;
  Art.Lift := Lift;
end;

end.
