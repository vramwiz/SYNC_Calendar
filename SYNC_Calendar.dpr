library SYNC_Calendar;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// AviUtl2 の DLL エントリーポイント。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
  Calendar_Settings in 'Source\Common\Calendar_Settings.pas',
  Calendar_Vector in 'Source\Common\Calendar_Vector.pas',
  Calendar_Glyphs in 'Source\Common\Calendar_Glyphs.pas',
  Calendar_Season in 'Source\Common\Calendar_Season.pas',
  Calendar_Design in 'Source\Common\Calendar_Design.pas',
  Calendar_Renderer in 'Source\Common\Calendar_Renderer.pas',
  Calendar_Audio in 'Source\Common\Calendar_Audio.pas',
  Calendar_Parameters in 'Source\Plugin\Filter\Calendar_Parameters.pas',
  SYNC_Calendar_FilterPlugin in 'Source\Plugin\Filter\SYNC_Calendar_FilterPlugin.pas';

{$R *.res}

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  Result := 0;
  try
    if Version < CALENDAR_REQUIRED_VERSION then Exit;
    SetCalendarHostVersion(Version);
    GetCalendarFilterTable;
    Result := 1;
  except
    // 初期化に失敗した場合は SDK の false を返す。
  end;
end;

procedure UninitializePlugin; cdecl;
begin
  // エフェクトの描画資源は func_destroy で回収される。
end;

function RequiredVersion: Cardinal; cdecl;
begin
  Result := CALENDAR_REQUIRED_VERSION;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := nil;
  try
    Result := GetCalendarFilterTable;
  except
    // DLL の外へ例外を伝播させない。
  end;
end;

exports
  RequiredVersion name 'RequiredVersion',
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
