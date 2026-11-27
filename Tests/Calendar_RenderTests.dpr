program Calendar_RenderTests;

{$APPTYPE CONSOLE}
{$POINTERMATH ON}

uses
  Winapi.Windows, System.SysUtils, System.Math, System.Classes, System.Hash,
  AviUtl2FilterTypes in '..\Source\Lib\AviUtl2FilterTypes.pas',
  Calendar_Settings in '..\Source\Common\Calendar_Settings.pas';

type
  TInit = function(Version: Cardinal): Byte; cdecl;
  TRequired = function: Cardinal; cdecl;
  TGetTable = function: PFILTER_PLUGIN_TABLE; cdecl;
  TDone = procedure; cdecl;
  PVertex = ^TVertexColorNorm;
  PItemPointer = ^Pointer;
  PSelectOption = ^TFILTER_ITEM_SELECT_ITEM;

var
  Table: PFILTER_PLUGIN_TABLE;
  Obj: TOBJECT_INFO;
  Scene: TSCENE_INFO;
  Video: TFILTER_PROC_VIDEO;
  Audio: TFILTER_PROC_AUDIO;
  View: TOBJECT_IMAGE_PARAM;
  Mesh: TMemoryStream;
  Captured: TArray<Single>;
  OutputDir: string;
  AnchorW, AnchorH, CameraRead, ForcedCamera, AudioCalls, VertexCount: Integer;
  ImageSet, Culling, HasLift, RedNumber, RedWeekday, RedHeader, BlueHeader: Boolean;
  ItemKind, ItemEffect, ItemGlyph: PFILTER_ITEM_SELECT;
  Base, Target, Holidays: PFILTER_ITEM_STRING;
  Delay, Duration, Volume: PFILTER_ITEM_TRACK;
  HolidayColor: PFILTER_ITEM_COLOR;

procedure Check(OK: Boolean; const MessageText: string);
begin
  if not OK then raise Exception.Create(MessageText);
end;

procedure SetImage(Pixels: PPIXEL_RGBA; Width, Height: Integer); cdecl;
begin
  ImageSet := (Pixels <> nil) and (Width = 1) and (Height = 1);
end;

procedure SetAnchor(Width, Height: Integer); cdecl;
begin
  AnchorW := Width;
  AnchorH := Height;
end;

procedure SetCulling(Cull: Boolean); cdecl;
begin
  Culling := Cull;
end;

function GetOutput(Obj: OBJECT_HANDLE; Offset: Double; Output: POBJECT_IMAGE_PARAM;
  Size: Integer): Boolean; cdecl;
begin
  Result := (Obj = nil) and (Offset = 0) and (Size = SizeOf(View));
  if Result then Output^ := View;
end;

function Camera: Integer; cdecl;
begin
  Inc(CameraRead);
  Result := ForcedCamera;
end;

function DrawPoly(VertexType: Integer; Vertices: Pointer; Count: Integer;
  Resource: PWideChar): Boolean; cdecl;
var
  I: Integer;
  V: TVertexColorNorm;
begin
  Result := False;
  if (VertexType <> VERTEX_TRIANGLE_COLOR_NORM) or (Resource <> nil) or
    (not Culling) or (Count <= 0) or (Count mod 3 <> 0) then Exit;
  for I := 0 to Count - 1 do
  begin
    V := PVertex(Vertices)[I];
    if not (Abs(V.X) < 1500) or not (Abs(V.Y) < 1500) or not (Abs(V.Z) < 1500) or
      not (V.A >= 0) or not (V.A <= 1) or
      (Abs(V.NX * V.NX + V.NY * V.NY + V.NZ * V.NZ - 1) > 0.001) then Exit;
    HasLift := HasLift or (V.Z < -25);
    if (V.R = 1) and (V.G = 0) and (V.B = 0) then
    begin
      RedHeader := RedHeader or (V.Y < -170);
      RedNumber := RedNumber or (Abs(V.Y) < 130);
      RedWeekday := RedWeekday or (V.Y > 200);
    end;
    if (V.R = 0) and (V.G = 0) and (V.B = 1) then
      BlueHeader := BlueHeader or (V.Y < -170);
  end;
  Mesh.WriteBuffer(PVertex(Vertices)^, Count * SizeOf(TVertexColorNorm));
  Inc(VertexCount, Count);
  Result := True;
end;

procedure SetSamples(Buffer: System.PSingle; Channel: Integer); cdecl;
begin
  Inc(AudioCalls);
  if Channel = 0 then
    Move(Buffer^, Captured[0], Obj.SampleNum * SizeOf(Single))
  else if not CompareMem(Buffer, @Captured[0], Obj.SampleNum * SizeOf(Single)) then
    AudioCalls := -1;
end;

function Item(const Name, Kind: string): Pointer;
var
  I: PItemPointer;
  Entry: PFILTER_ITEM_STRING;
begin
  I := PItemPointer(Table^.Items);
  while I^ <> nil do
  begin
    Entry := PFILTER_ITEM_STRING(I^);
    if (string(Entry^.Name) = Name) and (string(Entry^.ItemType) = Kind) then Exit(Entry);
    Inc(I);
  end;
  raise Exception.Create('Missing item ' + Name);
end;

function Render(Time: Double; const Preview: string = ''): string;
var
  OutStream: TFileStream;
begin
  Obj.Time := Time;
  Mesh.Clear;
  VertexCount := 0;
  AnchorW := 0;
  AnchorH := 0;
  ImageSet := False;
  HasLift := False;
  RedNumber := False;
  RedWeekday := False;
  RedHeader := False;
  BlueHeader := False;
  Check(Table^.Func_Proc_Video(@Video) = 0, 'Video suppressed standard output');
  Check(ImageSet and (AnchorW > 400) and (AnchorH > 400) and not Culling,
    'Video callback setup or state restore');
  Check((VertexCount > 100) and (VertexCount < 40000), 'Invalid or excessive triangle geometry');
  Mesh.Position := 0;
  Result := THashSHA2.GetHashString(Mesh);
  if (OutputDir <> '') and (Preview <> '') then
  begin
    OutStream := TFileStream.Create(IncludeTrailingPathDelimiter(OutputDir) + Preview + '.mesh',
      fmCreate);
    try
      OutStream.WriteBuffer(AnchorW, SizeOf(AnchorW));
      OutStream.WriteBuffer(AnchorH, SizeOf(AnchorH));
      OutStream.WriteBuffer(Mesh.Memory^, Mesh.Size);
    finally
      OutStream.Free;
    end;
  end;
end;

procedure ResetParams;
begin
  ItemKind^.Value := Ord(ckMonth);
  ItemEffect^.Value := Ord(ceNone);
  ItemGlyph^.Value := Ord(gsMincho);
  Base^.Value := DefaultBaseDate;
  Target^.Value := DefaultTargetDate;
  Holidays^.Value := DefaultHolidays;
  Delay^.Value := 0;
  Duration^.Value := 1;
  Volume^.Value := 50;
end;

procedure VerifyTimeline;
var
  K: TCalendarKind;
  E: TCalendarEffect;
  Initial, Ended, Mid, Reverse, Invalid: string;
begin
  for K := Low(TCalendarKind) to High(TCalendarKind) do
  begin
    ResetParams;
    ItemKind^.Value := Ord(K);
    Initial := Render(0, 'kind-' + IntToStr(Ord(K)));
    Check(Initial = Render(12), 'None should ignore target');
    Base^.Value := DefaultTargetDate;
    Ended := Render(0);
    Check(Initial <> Ended, 'December and January meshes differ');
    Base^.Value := DefaultBaseDate;
    Delay^.Value := 0.25;
    for E := ceTurn to ceReverseFlutter do
    begin
      ItemEffect^.Value := Ord(E);
      Check(Render(0.12) = Initial, 'Hold before start');
      Check(Render(0.25) = Initial, 'Exact start');
      Mid := Render(0.65, 'turn-' + IntToStr(Ord(K)) + '-' + IntToStr(Ord(E)));
      Check(HasLift and (Mid <> Initial) and (Mid <> Ended), 'Curl draws 3D geometry');
      Check(Render(1.25) = Ended, 'Exact end');
      Check(Render(3) = Ended, 'Hold after end');
      Check(Render(0.65) = Mid, 'Deterministic after seeking backwards');
    end;
    ItemEffect^.Value := Ord(ceTurn);
    Mid := Render(0.625);
    ItemEffect^.Value := Ord(ceReverse);
    Base^.Value := DefaultTargetDate;
    Target^.Value := DefaultBaseDate;
    Reverse := Render(0.875);
    Check(Reverse = Mid, 'Reverse is exact inverse of normal page motion');
    Check(Render(0.25) = Ended, 'Descending starts on January');
    Check(Render(1.25) = Initial, 'Descending ends on December');
    Duration^.Value := 0;
    Check((Render(0.249) = Ended) and (Render(0.25) = Initial), 'Zero-length switch');
  end;
  ResetParams;
  ItemEffect^.Value := Ord(ceTurn);
  Base^.Value := '2026/12/01';
  Target^.Value := '2026/12/31';
  Check(Render(0.55) = Render(0), 'Month mode ignores the day');
  Base^.Value := '2028/2/30';
  Target^.Value := '00/1/1';
  Invalid := Render(1.5);
  Check(Invalid = Render(0), 'Invalid dates are stable');
  ResetParams;
  Check(Render(0) = Render(0, 'default'), 'Default workspace preview');
  Check(Render(0) = Invalid, 'Invalid date fallback');
end;

procedure VerifyGlyphStyles;
const
  Options: array[TCalendarGlyphStyle] of string = ('明朝', '丸ゴシック', '角ゴシック', '手書き体');
var
  S, Previous: TCalendarGlyphStyle;
  I: Integer;
  Glyphs, Turning: array[TCalendarGlyphStyle] of string;
  Monthly: string;
  Entry: PItemPointer;
  Option: PSelectOption;
begin
  Check(ItemGlyph^.Value = Ord(gsMincho), 'Mincho is the default');
  Option := PSelectOption(ItemGlyph^.List);
  for S := Low(TCalendarGlyphStyle) to High(TCalendarGlyphStyle) do
  begin
    I := Ord(High(TCalendarGlyphStyle)) - Ord(S);
    Check((string(Option[I].Name) = Options[S]) and (Option[I].Value = Ord(S)),
      'Glyph selector registration and ascending display IDs');
  end;
  Check(Option[Length(Options)].Name = nil, 'Glyph selector terminator');
  Entry := PItemPointer(Table^.Items);
  while Entry^ <> nil do
  begin
    Check(string(PFILTER_ITEM_STRING(Entry^)^.ItemType) <> 'hiderule',
      'Calendar parameters are registered without a hide rule');
    Inc(Entry);
  end;

  ResetParams;
  Monthly := Render(0);
  ItemGlyph^.Value := Ord(gsMincho);
  Check(Render(0) = Monthly, 'Glyph setting does not change the monthly layout');
  ItemKind^.Value := Ord(ckIllustrated);
  Monthly := Render(0);
  ItemGlyph^.Value := Ord(gsSquareGothic);
  Check(Render(0) = Monthly, 'Glyph setting does not change the illustrated layout');

  ItemKind^.Value := Ord(ckDay);
  Base^.Value := '2026/12/31';
  Target^.Value := '2027/1/1';
  for S := Low(S) to High(S) do
  begin
    ItemGlyph^.Value := Ord(S);
    ItemEffect^.Value := Ord(ceNone);
    Glyphs[S] := Render(0, 'glyph-' + IntToStr(Ord(S)));
    ItemEffect^.Value := Ord(ceTurn);
    Turning[S] := Render(0.45);
    Check(HasLift, 'Selected glyphs render during a page turn');
    Render(1, 'glyph-holiday-' + IntToStr(Ord(S)));
    Check(RedHeader and RedNumber and RedWeekday, 'Header, date and weekday share holiday color');
    for Previous := Low(S) to High(S) do
      if Previous < S then
      begin
        Check(Glyphs[S] <> Glyphs[Previous], 'Distinct glyph mesh before page turn');
        Check(Turning[S] <> Turning[Previous], 'Distinct glyph mesh during page turn');
      end;
  end;
  ItemEffect^.Value := Ord(ceNone);
  ItemGlyph^.Value := 99;
  Check(Render(0) = Glyphs[gsMincho], 'Unknown glyph style falls back to Mincho');
end;

procedure VerifyDates;
const
  Months: array[1..12] of PWideChar = ('2027/1/1','2027/2/1','2027/3/1','2027/4/1',
    '2027/5/1','2027/6/1','2027/7/1','2027/8/1','2027/9/1','2027/10/1','2027/11/1','2027/12/1');
var
  S: TCalendarSettings;
  Expected, Actual: string;
  M: Integer;
begin
  ResetParams;
  ItemKind^.Value := Ord(ckDay);
  Base^.Value := '2027/5/3';
  Holidays^.Value := '5/2,'#13#10'2/30, x';
  Expected := Render(0);
  Check(RedHeader and RedNumber and RedWeekday, 'Sunday holiday substitutes on Monday');
  Holidays^.Value := '05/03';
  Check(Render(0) = Expected, 'Direct and substitute holidays have same ink');
  HolidayColor^.R := 217;
  HolidayColor^.G := 30;
  Check(Render(0) <> Expected, 'Customized holiday color applied');
  HolidayColor^.R := 255;
  HolidayColor^.G := 0;
  Base^.Value := '2027/5/1';
  Holidays^.Value := '5/1';
  Render(0);
  Check(RedHeader and RedNumber and RedWeekday, 'Saturday holiday overrides Saturday color');
  Holidays^.Value := '';
  Render(0);
  Check(BlueHeader and not RedHeader and not RedNumber and not RedWeekday, 'Removing a holiday restores Saturday blue');
  Base^.Value := '2028/2/29';
  Holidays^.Value := '2/29';
  Render(0);
  Check(RedHeader and RedNumber and RedWeekday, 'Leap day is accepted');

  S := Default(TCalendarSettings);
  S.Kind := ckDay;
  S.Effect := ceFlutter;
  S.Duration := 1;
  ReadPages(S, '0001/1/1', '9999/12/31');
  Check(S.TargetPage - S.BasePage = 3652058, 'Full Gregorian range');
  Check(MakeSchedule(S).Turns = 18, 'Fast turns bounded');
  Base^.Value := '0001/1/1';
  Target^.Value := '9999/12/31';
  ItemEffect^.Value := Ord(ceFlutter);
  Actual := Render(0.61);
  Check(HasLift and (Actual = Render(0.61)), 'Long interval stable');
  Base^.Value := '2028/2/29';
  Target^.Value := '2028/2/29';
  Check(Render(0.67) = Render(0), 'Equal dates stay static');

  ResetParams;
  ItemKind^.Value := Ord(ckIllustrated);
  Expected := '';
  for M := 1 to 12 do
  begin
    Base^.Value := Months[M];
    Actual := Render(0, 'month-' + IntToStr(M));
    Check(Actual <> Expected, 'Illustrated pages vary by month');
    Expected := Actual;
  end;
  Base^.Value := '2028/12/01';
  Check(Render(0) <> Expected, 'Year changes illustrated page');
end;

function GetAudio(Index, Num: Integer): TArray<Single>;
begin
  SetLength(Captured, Num);
  Obj.SampleIndex := Index;
  Obj.SampleNum := Num;
  AudioCalls := 0;
  Check(Table^.Func_Proc_Audio(@Audio) = 1, 'Audio returns PCM output');
  Check(AudioCalls = 2, 'Stereo channels');
  Result := Copy(Captured);
end;

function Peak(const Samples: TArray<Single>): Single;
var
  Value: Single;
begin
  Result := 0;
  for Value in Samples do
    Result := Max(Result, Abs(Value));
end;

procedure VerifyAudio;
var
  Full, Block: TArray<Single>;
  MaxSample: Single;
begin
  ResetParams;
  ItemEffect^.Value := Ord(ceTurn);
  Delay^.Value := 0.25;
  Check(Peak(GetAudio(0, 12000)) = 0, 'Silent before effect');
  Full := GetAudio(12000, 48000);
  MaxSample := Peak(Full);
  Check((MaxSample > 0.01) and (MaxSample < 0.5), 'Paper PCM is bounded and audible');
  Block := GetAudio(12000 + 2000, 10003);
  Check(CompareMem(@Block[0], @Full[2000], Length(Block) * SizeOf(Single)),
    'Audio repeatable across block lengths and seeks');
  Check(Peak(GetAudio(60000, 1200)) = 0, 'Silent after effect');
  Volume^.Value := 100;
  Check(Abs(Peak(GetAudio(12000, 48000)) - 2 * MaxSample) < 0.0001, 'Volume scales linearly');
  Volume^.Value := 0;
  Check(Peak(GetAudio(12000, 48000)) = 0, 'Volume zero mutes');
  ResetParams;
  ItemEffect^.Value := Ord(ceFlutter);
  Base^.Value := '2024/1/1';
  Check(Peak(GetAudio(0, 48000)) > 0.01, 'Fast animation produces paper sound');
end;

procedure Run;
var
  Lib: HMODULE;
  Init: TInit;
  Required: TRequired;
  GetTable: TGetTable;
  Done: TDone;
  Older, CameraOff: string;
  I: Integer;
begin
  if ParamCount < 1 then raise Exception.Create('Usage: Calendar_RenderTests <AUF2> [mesh directory]');
  OutputDir := ParamStr(2);
  if OutputDir <> '' then ForceDirectories(OutputDir);
  Lib := LoadLibrary(PWideChar(ParamStr(1)));
  Check(Lib <> 0, 'Load production AUF2');
  Mesh := TMemoryStream.Create;
  try
    @Init := GetProcAddress(Lib, 'InitializePlugin');
    @Required := GetProcAddress(Lib, 'RequiredVersion');
    @GetTable := GetProcAddress(Lib, 'GetFilterPluginTable');
    @Done := GetProcAddress(Lib, 'UninitializePlugin');
    Check(Assigned(Init) and Assigned(Required) and Assigned(GetTable) and Assigned(Done), 'DLL exports');
    Check(Required() = 2011600, 'Minimum SDK version');
    Check((Init(2011599) = 0) and (Init(2011600) = 1), 'SDK version gate');

    Table := GetTable();
    Check((Table <> nil) and (string(Table^.Name) = 'カレンダー演出') and
      (string(Table^.Label_) = 'SYNC') and (Table^.Flag = 23), 'AV object plugin registration');
    ItemKind := Item('カレンダー種類', 'select');
    ItemEffect := Item('演出', 'select');
    ItemGlyph := Item('日めくりの字形', 'select');
    Base := Item('基準年月日', 'string');
    Target := Item('目標年月日', 'string');
    Holidays := Item('祝日', 'text');
    Delay := Item('演出開始までの時間', 'track');
    Duration := Item('演出時間', 'track');
    Volume := Item('音量', 'track');
    HolidayColor := Item('日曜日・祝日文字色', 'color');
    Check((ItemKind^.Value = 0) and (ItemEffect^.Value = 0) and
      (string(Base^.Value) = DefaultBaseDate) and (string(Target^.Value) = DefaultTargetDate) and
      (string(Holidays^.Value) = DefaultHolidays) and (Delay^.Value = 0) and
      (Duration^.Value = 1) and (Volume^.Value = 50), 'Registered defaults');

    Obj.ChannelNum := 2;
    Scene.SampleRate := 48000;
    Scene.Rate := 30;
    Scene.Scale := 1;
    Video.Scene := @Scene;
    Video.Object_ := @Obj;
    Video.SetImageData := SetImage;
    Video.SetDefaultAnchor := SetAnchor;
    Video.SetCullingState := SetCulling;
    Video.GetOutputImageParam := GetOutput;
    Video.DrawPoly := DrawPoly;
    Video.GetCameraMode := Camera;
    Video.UserData := Table^.Func_Create(1);
    Check(Video.UserData <> nil, 'Renderer session');
    Audio.Scene := @Scene;
    Audio.Object_ := @Obj;
    Audio.SetSampleData := SetSamples;

    View.Alpha := 1;
    View.SX := 1;
    View.SY := 1;
    View.SZ := 1;
    try
      VerifyGlyphStyles;
      VerifyTimeline;
      VerifyDates;
      VerifyAudio;
      ResetParams;
      ItemEffect^.Value := Ord(ceTurn);
      Older := Render(0.46);
      Check(CameraRead = 0, '2.1.16 gates newer callback');
      Check(Init(2011700) = 1, '2.1.17 initialization');
      CameraOff := Render(0.46);
      Check((CameraOff = Older) and (CameraRead = 1), '2.1.17 camera off fallback');
      ForcedCamera := 1;
      Check(Render(0.46) <> CameraOff, 'Camera GPU depth path');
      ResetParams;
      ForcedCamera := 0;
      I := CameraRead;
      Writeln('DEFAULT_SHA256=', Render(0));
      Check(CameraRead = I + 1, 'Uses camera API on supported host');
    finally
      Table^.Func_Destroy(1, Video.UserData);
    end;
    Done();
    Writeln('All calendar integration checks passed.');
  finally
    Mesh.Free;
    FreeLibrary(Lib);
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
