unit Calendar_Vector;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 用紙上のベクター図形を、色付き三角形に変換する。座標は下向きの Y を使う。

interface

uses System.Generics.Collections;

type
  TArtPoint = record
    X, Y: Single;
    Color: Cardinal;
    Alpha: Single;
  end;
  TArtTriangle = record
    P: array[0..2] of TArtPoint;
    Lift: Single;
  end;
  TArt = class(TList<TArtTriangle>)
  public
    Lift: Single; // 紙の手前側への距離
    procedure Triangle(const A, B, C: TArtPoint);
    procedure Polygon(const Points: array of TArtPoint);
    procedure Rect(X1, Y1, X2, Y2: Single; Color: Cardinal);
    procedure Gradient(X1, Y1, X2, Y2: Single; Top, Bottom: Cardinal;
      TopAlpha: Single = 1; BottomAlpha: Single = 1);
    procedure RoundRect(X1, Y1, X2, Y2, Radius: Single; Color: Cardinal);
    procedure Oval(X, Y, RX, RY: Single; Color: Cardinal; Sides: Integer = 16);
    procedure Stroke(const Points: array of TArtPoint; Width: Single; Caps: Boolean = True);
  end;

function Ink(X, Y: Single; Color: Cardinal; Alpha: Single = 1): TArtPoint;
function MixColor(A, B: Cardinal; Amount: Single): Cardinal;
// 三角形を Y の帯に切り出す。三角形の色・重なり順を維持する。
procedure ClipToBand(const Triangle: TArtTriangle; Top, Bottom: Single; Target: TArt);

implementation

uses System.Math;

function Ink(X, Y: Single; Color: Cardinal; Alpha: Single): TArtPoint;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Color := Color;
  Result.Alpha := Alpha;
end;

function MixColor(A, B: Cardinal; Amount: Single): Cardinal;
var
  Shift, Left, Right: Integer;
begin
  Result := 0;
  for Shift in [0, 8, 16] do
  begin
    Left := (A shr Shift) and 255;
    Right := (B shr Shift) and 255;
    Result := Result or (Cardinal(Round(Left + (Right - Left) * Amount)) shl Shift);
  end;
end;

procedure TArt.Triangle(const A, B, C: TArtPoint);
var
  T: TArtTriangle;
  Area: Single;
begin
  Area := (B.X - A.X) * (C.Y - A.Y) - (B.Y - A.Y) * (C.X - A.X);
  if Abs(Area) < 0.00001 then Exit;
  T.P[0] := A;
  if Area > 0 then
  begin
    T.P[1] := B;
    T.P[2] := C;
  end
  else
  begin
    T.P[1] := C;
    T.P[2] := B;
  end;
  T.Lift := Lift;
  Add(T);
end;

procedure TArt.Polygon(const Points: array of TArtPoint);
var
  I: Integer;
begin
  for I := 1 to High(Points) - 1 do Triangle(Points[0], Points[I], Points[I + 1]);
end;

procedure TArt.Rect(X1, Y1, X2, Y2: Single; Color: Cardinal);
begin
  Gradient(X1, Y1, X2, Y2, Color, Color);
end;

procedure TArt.Gradient(X1, Y1, X2, Y2: Single; Top, Bottom: Cardinal;
  TopAlpha, BottomAlpha: Single);
begin
  Polygon([Ink(X1, Y1, Top, TopAlpha), Ink(X2, Y1, Top, TopAlpha),
    Ink(X2, Y2, Bottom, BottomAlpha), Ink(X1, Y2, Bottom, BottomAlpha)]);
end;

procedure TArt.RoundRect(X1, Y1, X2, Y2, Radius: Single; Color: Cardinal);
const
  CornerSteps = 5;
var
  P: array[0..4 * (CornerSteps + 1) - 1] of TArtPoint;
  CX, CY, Angle: Single;
  Corner, J: Integer;
begin
  for Corner := 0 to 3 do
  begin
    if Corner in [0, 1] then CX := X2 - Radius else CX := X1 + Radius;
    if Corner in [1, 2] then CY := Y2 - Radius else CY := Y1 + Radius;
    for J := 0 to CornerSteps do
    begin
      Angle := (Corner - 1 + J / CornerSteps) * (Pi / 2);
      P[Corner * (CornerSteps + 1) + J] :=
        Ink(CX + Radius * Cos(Angle), CY + Radius * Sin(Angle), Color);
    end;
  end;
  Polygon(P);
end;

procedure TArt.Oval(X, Y, RX, RY: Single; Color: Cardinal; Sides: Integer);
var
  Center, Prev, Next: TArtPoint;
  I: Integer;
  Angle: Single;
begin
  Center := Ink(X, Y, Color);
  Prev := Ink(X + RX, Y, Color);
  for I := 1 to Sides do
  begin
    Angle := 2 * Pi * I / Sides;
    Next := Ink(X + RX * Cos(Angle), Y + RY * Sin(Angle), Color);
    Triangle(Center, Prev, Next);
    Prev := Next;
  end;
end;

procedure TArt.Stroke(const Points: array of TArtPoint; Width: Single; Caps: Boolean);
var
  I: Integer;
  PrevLeft, PrevRight, Left, Right: TArtPoint;
  DX, DY, NX, NY, NextX, NextY, D, Half: Single;

  procedure EdgeNormal(Segment: Integer; out X, Y: Single);
  var
    Length: Single;
  begin
    X := Points[Segment].Y - Points[Segment + 1].Y;
    Y := Points[Segment + 1].X - Points[Segment].X;
    Length := Max(0.0001, Sqrt(X * X + Y * Y));
    X := X / Length;
    Y := Y / Length;
  end;

begin
  if Length(Points) < 2 then Exit;
  Half := Width * 0.5;
  EdgeNormal(0, NX, NY);
  PrevLeft := Ink(Points[0].X + NX * Half, Points[0].Y + NY * Half, Points[0].Color);
  PrevRight := Ink(Points[0].X - NX * Half, Points[0].Y - NY * Half, Points[0].Color);
  for I := 1 to High(Points) do
  begin
    NextX := NX;
    NextY := NY;
    if I < High(Points) then EdgeNormal(I, NextX, NextY);
    D := Half / Max(0.65, 1 + NX * NextX + NY * NextY);
    DX := (NX + NextX) * D;
    DY := (NY + NextY) * D;
    Left := Ink(Points[I].X + DX, Points[I].Y + DY, Points[I].Color);
    Right := Ink(Points[I].X - DX, Points[I].Y - DY, Points[I].Color);
    Polygon([PrevLeft, Left, Right, PrevRight]);
    PrevLeft := Left;
    PrevRight := Right;
    NX := NextX;
    NY := NextY;
  end;
  if Caps then
  begin
    Oval(Points[0].X, Points[0].Y, Half, Half, Points[0].Color, 8);
    Oval(Points[High(Points)].X, Points[High(Points)].Y, Half, Half,
      Points[High(Points)].Color, 8);
  end;
end;

type
  TClippedPolygon = array[0..5] of TArtPoint;

function ClipEdge(const Input: TClippedPolygon; Count: Integer; Y: Single;
  LowerBound: Boolean; out Output: TClippedPolygon): Integer;
var
  I: Integer;
  A, B: TArtPoint;
  AInside, BInside: Boolean;
  F: Single;
begin
  Result := 0;
  if Count = 0 then Exit;
  A := Input[Count - 1];
  AInside := (LowerBound and (A.Y >= Y)) or (not LowerBound and (A.Y <= Y));
  for I := 0 to Count - 1 do
  begin
    B := Input[I];
    BInside := (LowerBound and (B.Y >= Y)) or (not LowerBound and (B.Y <= Y));
    if AInside <> BInside then
    begin
      F := (Y - A.Y) / (B.Y - A.Y);
      Output[Result] := Ink(A.X + (B.X - A.X) * F, Y, MixColor(A.Color, B.Color, F),
        A.Alpha + (B.Alpha - A.Alpha) * F);
      Inc(Result);
    end;
    if BInside then
    begin
      Output[Result] := B;
      Inc(Result);
    end;
    A := B;
    AInside := BInside;
  end;
end;

procedure ClipToBand(const Triangle: TArtTriangle; Top, Bottom: Single; Target: TArt);
var
  A, B: TClippedPolygon;
  I, Count: Integer;
begin
  if (Triangle.P[0].Y >= Top) and (Triangle.P[0].Y <= Bottom) and
    (Triangle.P[1].Y >= Top) and (Triangle.P[1].Y <= Bottom) and
    (Triangle.P[2].Y >= Top) and (Triangle.P[2].Y <= Bottom) then
  begin
    Target.Add(Triangle);
    Exit;
  end;
  for I := 0 to 2 do A[I] := Triangle.P[I];
  Count := ClipEdge(A, 3, Top, True, B);
  Count := ClipEdge(B, Count, Bottom, False, A);
  Target.Lift := Triangle.Lift;
  for I := 1 to Count - 2 do Target.Triangle(A[0], A[I], A[I + 1]);
end;

end.
