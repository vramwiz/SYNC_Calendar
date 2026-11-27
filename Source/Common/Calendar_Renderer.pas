unit Calendar_Renderer;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 紙面を帯に分けて変形し、AviUtl2 の D3D フレームバッファへ送る。
// SDK ポインターは描画コールバック中だけ使い、キャッシュには紙面の座標と色だけを保持する。

interface

uses System.Generics.Collections, System.Generics.Defaults, AviUtl2FilterTypes,
  Calendar_Settings, Calendar_Vector, Calendar_Design;

const
  BandCount = 24;

type
  TPageBands = class
  public
    Page: Integer;
    Simple: Boolean;
    Art: array[0..BandCount - 1] of TArt;
    constructor Create;
    destructor Destroy; override;
    // 紙面の図形順を維持しながら帯ごとの三角形を作り直す。Source は呼び出し元が所有する。
    procedure Fill(Source: TArt; const Layout: TCalendarLayout);
  end;

  TBandPose = record
    Top, Bottom, Middle, X, Y, Z, EndX, EndY, EndZ: Single;
    SinRoll, CosRoll, SinTop, CosTop, SinBottom, CosBottom, TopLight, BottomLight: Single;
  end;

  TDrawBand = record
    Art: TArt;
    Pose: TBandPose;
    Opacity: Single;
    Back: Boolean;
    Depth: Double;
    Order: Integer;
  end;

  TCalendarRenderer = class
  private
    FSettings: TCalendarSettings;
    FReady: Boolean;
    FLayout: TCalendarLayout;
    // 表面は下の紙と動く紙の2枚を保持する。日付や字形の変化に応じて再生成する。
    FPages: array[0..1] of TPageBands;
    FBack: TPageBands;
    FBoard, FBoardBack, FBinding, FShadow, FWork: TArt;
    FBatches: TList<TDrawBand>;
    FVertices: TList<TVertexColorNorm>;
    FCompare: IComparer<TDrawBand>;
    procedure UpdateDesign(const S: TCalendarSettings);
    procedure LoadPage(Slot, Index: Integer; Simple: Boolean);
    procedure Queue(Art: TArt; const Pose: TBandPose; Opacity: Single = 1;
      Back: Boolean = False);
    procedure QueuePages(const Frame: TCalendarFrame; Fast: Boolean);
    procedure Emit(const Batch: TDrawBand);
  public
    constructor Create;
    destructor Destroy; override;
    // 継承元の描画パラメータを SDK に適用させる。呼び出し側で標準の二重描画を止める。
    procedure Draw(Video: PFILTER_PROC_VIDEO; const S: TCalendarSettings;
      CameraAPIAvailable: Boolean);
  end;

implementation

uses System.Math, System.SysUtils;

const
  // 標準描画の座標変換に必要な画像入力。実際の紙面は DrawPoly が出力する。
  AnchorPixel: TPIXEL_RGBA = (R:255; G:255; B:255; A:255);

function Smooth(X: Double): Double;
begin
  X := EnsureRange(X, 0.0, 1.0);
  Result := X * X * (3 - 2 * X);
end;

function FlatPose(Middle, Z: Single): TBandPose;
begin
  Result := Default(TBandPose);
  Result.Middle := Middle;
  Result.Z := Z;
  Result.CosRoll := 1;
  Result.CosTop := 1;
  Result.CosBottom := 1;
  Result.TopLight := 1;
  Result.BottomLight := 1;
end;

function CompareBands(const A, B: TDrawBand): Integer;
begin
  if A.Depth > B.Depth then Exit(-1);
  if A.Depth < B.Depth then Exit(1);
  Result := A.Order - B.Order;
end;

constructor TPageBands.Create;
var
  I: Integer;
begin
  inherited;
  Page := -1;
  for I := Low(Art) to High(Art) do Art[I] := TArt.Create;
end;

destructor TPageBands.Destroy;
var
  Item: TArt;
begin
  for Item in Art do Item.Free;
  inherited;
end;

procedure TPageBands.Fill(Source: TArt; const Layout: TCalendarLayout);
var
  T: TArtTriangle;
  I, First, Last: Integer;
  Height, Top, Bottom: Single;
begin
  Height := (Layout.Bottom - Layout.Top) / BandCount;
  for I := Low(Art) to High(Art) do Art[I].Clear;
  for T in Source do
  begin
    Top := Min(T.P[0].Y, Min(T.P[1].Y, T.P[2].Y));
    Bottom := Max(T.P[0].Y, Max(T.P[1].Y, T.P[2].Y));
    First := EnsureRange(Floor((Top - Layout.Top) / Height), 0, BandCount - 1);
    Last := EnsureRange(Floor((Bottom - Layout.Top) / Height), 0, BandCount - 1);
    for I := First to Last do
    begin
      Top := Layout.Top + I * Height;
      Bottom := Layout.Top + (I + 1) * Height;
      if I = 0 then Top := Layout.Top;
      if I = BandCount - 1 then Bottom := Layout.Bottom;
      ClipToBand(T, Top, Bottom, Art[I]);
    end;
  end;
end;

constructor TCalendarRenderer.Create;
begin
  inherited;
  FPages[0] := TPageBands.Create;
  FPages[1] := TPageBands.Create;
  FBack := TPageBands.Create;
  FBoard := TArt.Create;
  FBoardBack := TArt.Create;
  FBinding := TArt.Create;
  FShadow := TArt.Create;
  FWork := TArt.Create;
  FBatches := TList<TDrawBand>.Create;
  FVertices := TList<TVertexColorNorm>.Create;
  FCompare := TComparer<TDrawBand>.Construct(CompareBands);
end;

destructor TCalendarRenderer.Destroy;
begin
  FVertices.Free;
  FBatches.Free;
  FWork.Free;
  FShadow.Free;
  FBinding.Free;
  FBoardBack.Free;
  FBoard.Free;
  FBack.Free;
  FPages[1].Free;
  FPages[0].Free;
  inherited;
end;

procedure TCalendarRenderer.UpdateDesign(const S: TCalendarSettings);
var
  L: TCalendarLayout;
  BodyChanged: Boolean;
begin
  BodyChanged := not FReady or (FSettings.Kind <> S.Kind) or
    (FSettings.Colors[ccPaper] <> S.Colors[ccPaper]);
  if BodyChanged or ((S.Kind = ckDay) and (FSettings.DayGlyph <> S.DayGlyph)) or
    not CompareMem(@FSettings.Colors, @S.Colors, SizeOf(S.Colors)) or
    not CompareMem(@FSettings.Holidays, @S.Holidays, SizeOf(S.Holidays)) then
  begin
    FPages[0].Page := -1;
    FPages[1].Page := -1;
  end;
  FSettings := S;
  FReady := True;
  if not BodyChanged then Exit;

  L := CalendarLayout(S.Kind);
  FLayout := L;
  FBoard.Clear;
  FBoardBack.Clear;
  FBinding.Clear;
  AddBackboard(FBoard, L, S.Colors[ccPaper]);
  FBoardBack.RoundRect(-L.Width * 0.5, -L.Height * 0.5, L.Width * 0.5, L.Height * 0.5, 15, $293641);
  AddBinding(FBinding, L, S.Kind);
  FWork.Clear;
  AddPage(FWork, L, S, S.BasePage, True, False);
  FBack.Fill(FWork, L);
end;

procedure TCalendarRenderer.LoadPage(Slot, Index: Integer; Simple: Boolean);
var
  Page: TPageBands;
begin
  Page := FPages[Slot];
  if (Page.Page = Index) and (Page.Simple = Simple) then Exit;
  FWork.Clear;
  AddPage(FWork, FLayout, FSettings, Index, False, Simple);
  Page.Fill(FWork, FLayout);
  Page.Page := Index;
  Page.Simple := Simple;
end;

procedure TCalendarRenderer.Queue(Art: TArt; const Pose: TBandPose;
  Opacity: Single; Back: Boolean);
var
  B: TDrawBand;
begin
  if (Art.Count = 0) or (Opacity <= 0) then Exit;
  B.Art := Art;
  B.Pose := Pose;
  B.Opacity := Opacity;
  B.Back := Back;
  B.Depth := 0;
  B.Order := FBatches.Count;
  FBatches.Add(B);
end;

procedure TCalendarRenderer.QueuePages(const Frame: TCalendarFrame; Fast: Boolean);
var
  I: Integer;
  P, ReleaseAmount, Alpha, Height, PaperLength, Y, Z, Theta, CurlStart, Curl,
    Spin, SinRoll, CosRoll, DY, DZ, ShadowY, ShadowOpacity, NextY, NextZ,
    SinTop, CosTop, SinBottom, CosBottom: Double;
  Pose: TBandPose;
  L: TCalendarLayout;

  function Angle(Position: Double): Double;
  begin
    Result := Min(2.96, Curl * Smooth((Position - CurlStart) / (1 - CurlStart)) +
      0.65 * Smooth((P - 0.37) / 0.63));
  end;

  function PaperLight(Theta: Double; Back: Boolean): Single;
  begin
    if Back then Exit(0.70 + 0.30 * Abs(Cos(Theta)));
    Result := 1 - 0.22 * (1 - Max(0.0, Cos(Theta))) - 0.09 * Abs(Sin(Theta));
  end;

begin
  L := FLayout;
  Height := (L.Bottom - L.Top) / BandCount;
  if not Frame.Turning or (Frame.Progress >= 1) then
  begin
    LoadPage(0, Frame.UnderPage, False);
    for I := 0 to BandCount - 1 do
      Queue(FPages[0].Art[I], FlatPose(L.Top + (I + 0.5) * Height, 0));
    Exit;
  end;
  if Frame.Progress <= 0 then
  begin
    LoadPage(0, Frame.TurningPage, False);
    for I := 0 to BandCount - 1 do
      Queue(FPages[0].Art[I], FlatPose(L.Top + (I + 0.5) * Height, 0));
    Exit;
  end;

  LoadPage(0, Frame.UnderPage, False);
  LoadPage(1, Frame.TurningPage, Frame.Simple);
  for I := 0 to BandCount - 1 do
    Queue(FPages[0].Art[I], FlatPose(L.Top + (I + 0.5) * Height, 0));

  P := Frame.Progress;
  if Fast then P := (P + Smooth(P)) * 0.5;
  ReleaseAmount := Smooth((P - 0.48) / 0.52);
  Alpha := 1 - Smooth((P - 0.79) / 0.21);
  CurlStart := 0.76 * (1 - Smooth(P / 0.63));
  Curl := 2.74 * Smooth(P / 0.46);
  Spin := -0.045 * Smooth((P - 0.25) / 0.26) - 0.165 * ReleaseAmount;
  SinCos(Spin, SinRoll, CosRoll);
  Y := 0;
  Z := -1.15 - ReleaseAmount * 54;
  PaperLength := L.Bottom - L.Top;
  SinCos(Angle(0), SinTop, CosTop);
  for I := 0 to BandCount - 1 do
  begin
    Theta := Angle((I + 0.5) / BandCount);
    SinCos(Theta, DZ, DY);
    DZ := -DZ;
    // 紙の長さを保ちながら、接線を積分して手前に曲げる。
    NextY := Y + Height * DY;
    NextZ := Z + Height * DZ;
    Pose.Top := L.Top + I * Height;
    Pose.Bottom := L.Top + (I + 1) * Height;
    if I = BandCount - 1 then Pose.Bottom := L.Bottom;
    Pose.Middle := (Pose.Top + Pose.Bottom) * 0.5;
    Pose.X := ReleaseAmount * FLayout.Width * 0.17 - Y * SinRoll;
    Pose.EndX := ReleaseAmount * FLayout.Width * 0.17 - NextY * SinRoll;
    Pose.Y := L.Top + Y * CosRoll - ReleaseAmount * PaperLength * 0.99;
    Pose.EndY := L.Top + NextY * CosRoll - ReleaseAmount * PaperLength * 0.99;
    Pose.Z := Z;
    Pose.EndZ := NextZ;
    Pose.SinRoll := SinRoll;
    Pose.CosRoll := CosRoll;
    SinCos(Angle((I + 1) / BandCount), SinBottom, CosBottom);
    Pose.SinTop := SinTop;
    Pose.CosTop := CosTop;
    Pose.SinBottom := SinBottom;
    Pose.CosBottom := CosBottom;
    Pose.TopLight := PaperLight(Angle(I / BandCount), False);
    Pose.BottomLight := PaperLight(Angle((I + 1) / BandCount), False);
    Queue(FPages[1].Art[I], Pose, Alpha);
    Pose.TopLight := PaperLight(Angle(I / BandCount), True);
    Pose.BottomLight := PaperLight(Angle((I + 1) / BandCount), True);
    Queue(FBack.Art[I], Pose, Alpha, True);
    Y := NextY;
    Z := NextZ;
    SinTop := SinBottom;
    CosTop := CosBottom;
  end;

  ShadowOpacity := 0.19 * Smooth(P / 0.28) * (1 - Smooth((P - 0.60) / 0.29));
  if ShadowOpacity > 0 then
  begin
    ShadowY := Min(L.Bottom, Max(L.Top + 7, L.Top + Y * CosRoll -
      ReleaseAmount * PaperLength * 0.99));
    FShadow.Clear;
    FShadow.Lift := 0;
    FShadow.Gradient(L.Left + 7, Max(L.Top + 7, ShadowY - 16), L.Right - 7,
      Min(L.Bottom - 3, ShadowY + 29), $41454D, $41454D, 0.82, 0);
    Queue(FShadow, FlatPose(ShadowY, -1.04), ShadowOpacity);
  end;
end;

procedure TCalendarRenderer.Emit(const Batch: TDrawBand);
var
  T: TArtTriangle;
  Point: TArtPoint;
  V: TVertexColorNorm;
  I, Corner, Side: Integer;
  Lift, Light, BandHeight, F, Inv, DX, DY, NormalLength: Single;
  P: TBandPose;
begin
  P := Batch.Pose;
  BandHeight := P.Bottom - P.Top;
  Side := 1;
  if Batch.Back then Side := -1;
  for T in Batch.Art do
  begin
    Lift := T.Lift;
    if Batch.Back then Lift := Lift + 0.42;
    for I := 0 to 2 do
    begin
      Corner := I;
      if Batch.Back and (I <> 0) then Corner := 3 - I;
      Point := T.P[Corner];
      Light := P.TopLight;
      if BandHeight > 0 then
      begin
        F := EnsureRange((Point.Y - P.Top) / BandHeight, 0.0, 1.0);
        Inv := 1 - F;
        DX := P.SinTop * Inv + P.SinBottom * F;
        DY := P.CosTop * Inv + P.CosBottom * F;
        NormalLength := Side / Sqrt(DX * DX + DY * DY);
        V.NX := DX * NormalLength * P.SinRoll;
        V.NY := -DX * NormalLength * P.CosRoll;
        V.NZ := -DY * NormalLength;
        V.X := P.X * Inv + P.EndX * F + Point.X * P.CosRoll + Lift * V.NX;
        V.Y := P.Y * Inv + P.EndY * F + Point.X * P.SinRoll + Lift * V.NY;
        V.Z := P.Z * Inv + P.EndZ * F + Lift * V.NZ;
        Light := P.TopLight * Inv + P.BottomLight * F;
      end
      else
      begin
        V.NX := 0;
        V.NY := 0;
        V.NZ := -Side;
        V.X := Point.X;
        V.Y := Point.Y;
        V.Z := P.Z + Lift * V.NZ;
      end;
      V.R := ((Point.Color shr 16) and 255) * (Light / 255);
      V.G := ((Point.Color shr 8) and 255) * (Light / 255);
      V.B := (Point.Color and 255) * (Light / 255);
      V.A := Batch.Opacity * Point.Alpha;
      FVertices.Add(V);
    end;
  end;
end;

procedure TCalendarRenderer.Draw(Video: PFILTER_PROC_VIDEO; const S: TCalendarSettings;
  CameraAPIAvailable: Boolean);
var
  Frame: TCalendarFrame;
  Output: TOBJECT_IMAGE_PARAM;
  HasOutput, CameraDepth: Boolean;
  SX, CX, SY, CY, AxisX, AxisY, AxisZ, CenterX, CenterY, CenterZ: Double;
  I, Offset, Count: Integer;
  B: TDrawBand;
begin
  if not Assigned(Video^.DrawPoly) then Exit;
  UpdateDesign(S);
  Frame := CalendarFrame(MakeSchedule(S), Video^.Object_^.Time);
  if Assigned(Video^.SetImageData) then Video^.SetImageData(@AnchorPixel, 1, 1);
  if Assigned(Video^.SetDefaultAnchor) then
    Video^.SetDefaultAnchor(FLayout.Width, FLayout.Height);

  Output := Default(TOBJECT_IMAGE_PARAM);
  HasOutput := Assigned(Video^.GetOutputImageParam) and
    Video^.GetOutputImageParam(nil, 0, @Output, SizeOf(Output));
  if HasOutput and (Output.Alpha <= 0) then Exit;
  CameraDepth := (Video^.Object_^.Flag and OBJECT_FLAG_CAMERA_TARGET) <> 0;
  if CameraAPIAvailable and Assigned(Video^.GetCameraMode) then
    CameraDepth := Video^.GetCameraMode() <> 0;
  CameraDepth := CameraDepth and (not HasOutput or (Output.Alpha >= 1));

  FBatches.Clear;
  Queue(FBoard, FlatPose(0, 4));
  Queue(FBoardBack, FlatPose(0, 18), 1, True);
  QueuePages(Frame, S.Effect in [ceFlutter, ceReverseFlutter]);
  Queue(FBinding, FlatPose(FLayout.Top, 0));

  AxisX := 0;
  AxisY := 0;
  AxisZ := 1;
  if HasOutput and not CameraDepth then
  begin
    SinCos(DegToRad(Output.RX), SX, CX);
    SinCos(DegToRad(Output.RY), SY, CY);
    AxisX := -SY * Output.SX;
    AxisY := SX * CY * Output.SY;
    AxisZ := CX * CY * Output.SZ;
  end;
  for I := 0 to FBatches.Count - 1 do
  begin
    B := FBatches[I];
    if CameraDepth then
    begin
      // D3D が深度を扱うカメラ描画では、不透明な面の後に半透明な影と紙を描く。
      if B.Opacity < 1 then B.Depth := -1;
    end
    else
    begin
      CenterX := 0;
      CenterY := B.Pose.Middle;
      CenterZ := B.Pose.Z;
      if B.Pose.Bottom > B.Pose.Top then
      begin
        CenterX := (B.Pose.X + B.Pose.EndX) * 0.5;
        CenterY := (B.Pose.Y + B.Pose.EndY) * 0.5;
        CenterZ := (B.Pose.Z + B.Pose.EndZ) * 0.5;
      end;
      if B.Art = FBinding then CenterZ := CenterZ - 4;
      if B.Back then CenterZ := CenterZ + 0.21 * (B.Pose.CosTop + B.Pose.CosBottom);
      B.Depth := AxisX * CenterX + AxisY * CenterY + AxisZ * CenterZ;
    end;
    FBatches[I] := B;
  end;
  FBatches.Sort(FCompare);
  FVertices.Clear;
  for B in FBatches do Emit(B);

  if Assigned(Video^.SetCullingState) then Video^.SetCullingState(True);
  try
    Offset := 0;
    while Offset < FVertices.Count do
    begin
      Count := Min(12288, FVertices.Count - Offset);
      Video^.DrawPoly(VERTEX_TRIANGLE_COLOR_NORM, @FVertices.List[Offset], Count, nil);
      Inc(Offset, Count);
    end;
  finally
    if Assigned(Video^.SetCullingState) then Video^.SetCullingState(False);
  end;
end;

end.
