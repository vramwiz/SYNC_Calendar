unit SYNC_Calendar_FilterPlugin;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// メディアオブジェクト登録と、描画インスタンスの所有権を管理する。

interface

uses AviUtl2FilterTypes;

const
  CALENDAR_REQUIRED_VERSION = 2011600;

// DLL 初期化時に SDK バージョンを伝える。
procedure SetCalendarHostVersion(Version: Cardinal);
// DLL 所有のテーブルを返す。
function GetCalendarFilterTable: PFILTER_PLUGIN_TABLE;

implementation

uses System.SyncObjs, System.SysUtils, Winapi.Windows, PluginFilterTable,
  Calendar_Parameters, Calendar_Settings, Calendar_Renderer, Calendar_Audio;

type
  TCalendarSession = class
  public
    Lock: TCriticalSection;
    Renderer: TCalendarRenderer;
    constructor Create;
    destructor Destroy; override;
  end;

var
  TableRegistered: Boolean;
  CameraAPIAvailable: Boolean;

procedure SetCalendarHostVersion(Version: Cardinal);
begin
  CameraAPIAvailable := Version >= 2011700;
end;

constructor TCalendarSession.Create;
begin
  inherited;
  Lock := TCriticalSection.Create;
  Renderer := TCalendarRenderer.Create;
end;

destructor TCalendarSession.Destroy;
begin
  Renderer.Free;
  Lock.Free;
  inherited;
end;

function CalendarVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  Session: TCalendarSession;
  S: TCalendarSettings;
begin
  Result := 0; // DrawPoly が最終フレームバッファへ出力する。
  if (Video = nil) or (Video^.Object_ = nil) or (Video^.UserData = nil) then Exit;
  try
    S := ReadCalendarSettings;
    Session := TCalendarSession(Video^.UserData);
    Session.Lock.Acquire;
    try
      Session.Renderer.Draw(Video, S, CameraAPIAvailable);
    finally
      Session.Lock.Release;
    end;
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Calendar video: ' + E.Message));
  end;
end;

function CalendarAudio(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;
begin
  Result := 0;
  if (Audio = nil) or (Audio^.Object_ = nil) or not Assigned(Audio^.SetSampleData) then Exit;
  try
    DrawCalendarAudio(Audio, ReadCalendarSettings);
    Result := 1;
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Calendar audio: ' + E.Message));
  end;
end;

function CreateCalendar(EffectID: Int64): Pointer; cdecl;
begin
  Result := nil;
  try
    Result := TCalendarSession.Create;
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Calendar create: ' + E.Message));
  end;
end;

procedure DestroyCalendar(EffectID: Int64; UserData: Pointer); cdecl;
begin
  try
    TCalendarSession(UserData).Free;
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Calendar destroy: ' + E.Message));
  end;
end;

function GetCalendarFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not TableRegistered then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_AUDIO or FILTER_FLAG_INPUT or
      FILTER_FLAG_USERDATA, 'カレンダー演出', 'SYNC',
      'カレンダー演出 / SYNC_Calendar v1.0.0', CalendarVideo, CalendarAudio);
    RegisterCalendarParameters;
    GetPluginTable^.Func_Create := CreateCalendar;
    GetPluginTable^.Func_Destroy := DestroyCalendar;
    TableRegistered := True;
  end;
  Result := GetPluginTable;
end;

end.
