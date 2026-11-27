# SYNC_Calendar 作業ノート

## プロジェクトの前提

- プロジェクトは `SYNC_Calendar.dproj`、グループは「SYNC」、登録名は「カレンダー演出」。本番は Win64 の `SYNC_Calendar.auf2` 1 本。
- プロジェクト構成・設定項目の登録基盤は `D:\DelphiProg\MyApp\SYNC_WeatherFX` を継承した。D3D 描画と SDK の定義は `D:\DelphiProg\MyApp\SYNC_Book` を参考にした。
- 利用者向けの初期値と操作は [README.md](README.md) を参照。

## ビルド

Delphi 37.0 / Win64。IDE では `SYNC_Calendar.dproj` を直接開く。プロジェクトルートから Debug・Release の順にビルドし、警告・エラーと AUF2 の更新を確認する。

```powershell
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_Calendar.dproj /t:Rebuild /p:Config=Debug /p:Platform=Win64'
.\Tests\run_tests.ps1
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_Calendar.dproj /t:Rebuild /p:Config=Release /p:Platform=Win64'
.\Tests\run_tests.ps1
```

- Win64 の Debug / Release は `C:\ProgramData\aviutl2\Plugin\SYNC_Calendar` に出力する。出力先は両構成で共通なので、構成別に確認する場合はそれぞれのビルド直後に検査する。
- ビルド後イベントはコピー元と同じ `copy ... && del ...`。DLL を AUF2 へコピーし、成功後に DLL を削除する。Release では RSM も削除する。DCU は `Win64\Debug\DCU` / `Win64\Release\DCU` に置く。
- デバッガーホストは両構成とも `D:\aviutl2_v2.1.16\aviutl2.exe`。MSBuild の結果と IDE 内の表示・ビルド結果は区別する。
- ユニット追加時は `.dpr` の `in` と `.dproj` の `DCCReference` を揃える。検索パスは `Source\Common`、`Source\Lib`、`Source\Lib\FilterTable`、`Source\Plugin\Filter`。IDE で開いたまま両ファイルを外部更新した場合はプロジェクトを開き直す。
- ビルド・検査にはアプリを起動せず、検査 EXE が本番 AUF2 の登録と SDK コールバックを確認する。アプリを使った表示確認は MSBuild・単体検査と区別して記録する。

## 実装と検査

- `Source/Plugin/Filter` は DLL 内の登録、SDK 項目の読み取り、エフェクトごとの描画資源を担当する。
- `Calendar_Settings` は暦、祝日、時刻からの紙面選択を担当する。短時間に大きな範囲を指定した場合は通常で毎秒5枚相当、ペラペラで毎秒18枚相当を目安に中間日を選ぶ。めくり回数の上限は通常240回、ペラペラ720回。
- `Calendar_Vector`、`Calendar_Glyphs`、`Calendar_Season`、`Calendar_Design` は用紙、文字と季節のイラストを色付き三角形にする。
- `Calendar_Renderer` は24帯に分けた紙の表裏と法線を生成し、SDK の `DrawPoly` に渡す。一度の描画で日付入りの紙面は最大2枚。カメラ対象かどうかは 2.1.16 ではオブジェクトフラグ、2.1.17 以降では SDK の `get_camera_mode` から読み取る。カメラがないときは標準回転に合わせた奥行き順を補う。
- `Calendar_Audio` はオブジェクト開始からの音声サンプル位置で紙音を計算する。状態を引き継がず、分割出力でも同じ位置の波形が一致する。
- `Tests/run_tests.ps1` は配置済み AUF2 の登録、始点・終点・逆シーク、祝日・うるう年、全12か月の風景、カメラの互換経路、音声の時間・音量と再現性を検査する。`-MeshDirectory` で描画コールバックが受け取った頂点を保存できる。

## 共通作業規則

- ユニット先頭に目的と責務を書く。公開処理の入力・出力と、必要な場合は副作用・所有権・保存対象を書く。
- 日本語を含む `.pas`・`.dpr`・Windows PowerShell 用 `.ps1` は UTF-8 BOM 付き、改行は CRLF。1ユニットは約1,500行を目安に責務で分割し、フォームの `.pas` と `.dfm` は同じフォルダーに置く。
- SDK 型の順序・サイズ・配置を変える場合は公式ヘッダーと照合する。ホスト所有ポインターはコールバックの外へ保存せず、Delphi 例外は DLL 境界で処理する。
- コピー元のプロジェクト、既存の AUP2、他のプラグインは変更しない。

## Setup

初回公開用の ZIP とカタログは `setup/make_release_zip.bat` で作成する。出力名は `SYNC_Calendar.zip` と `SYNC_Calendar.catalog.json`。カタログは `v1.0.0` から始め、ZIP に収める本番 AUF2 の XXH3-128 を使用する。具体的な引数と必要なツールは [setup/README.md](setup/README.md) に記載する。

## AviUtl2カタログ登録時の共通ルール

1. **概要は35文字以内。** `Setup/*.catalog.json` の `summary` は、JSONのエスケープ表記ではなく実際の表示文字列を数える。機能の詳細や補足は概要に詰め込まず、説明・READMEに記載する。
2. **既存タグを優先する。** [公開カタログの `index.json`](https://github.com/Neosku/aviutl2-catalog-data/blob/main/index.json) で、同じ製品や近い用途に使われているタグの表記を確認し、用途を表すものだけを選ぶ。同義語を重ねたり、製品ごとに新しいタグを量産したりしない。
3. **配布専用フォルダー単位で導入・削除する。** ZIP内を製品専用フォルダーにまとめ、ダウンロード・展開後の配置はフォルダーの `copy` 1件、アンインストールはその専用フォルダーだけを指定する `delete` 1件を基本とする。共有フォルダーや、ユーザー素材・設定を含むフォルダーは一括削除しない。既存パッケージで変更する際は、配布ZIPの配置とセットアップスクリプトの検証条件も確認し、整合しない場合は既存の手順を維持する。

## 2026-11-27 の検査結果

- Delphi 37.0 の Win64 Debug / Release を MSBuild で再ビルドし、両方とも警告0・エラー0。本番 AUF2 を読み込む検査は両構成で成功し、採取した描画頂点28件の SHA-256 が一致した。
- 配置済み Release は 1,759,232 バイト。SHA-256 は 0F508EED2E1377BCEB03B8362504C77BFFFAFA2D7995D078DDD6906A32292DA9。ログは Win64/BuildLogs に保存した。
- setup の5ファイルは ZIP を含めてコピー元と SHA-256 が一致した。描画頂点から作成した確認画像は Win64/CalendarTests に保存した。AviUtl2 内のプレビュー・カメラ画質・音の聴感は実機未確認。


## v1.0.0 配布前の確認（2026-11-27）

- 本体ソースの最長ユニットは Calendar_Renderer.pas の481行。共通作業規則に沿い、公開処理の入出力と描画資源の所有権を補足した。
- Win64 Debug / Release とも警告0・エラー0。本番 AUF2 の検査に合格し、採取した36件の描画頂点は両構成および直前の Release と一致した。
- SYNC_Calendar.zip の6ファイルを原本と照合した。SYNC_Calendar.catalog.json の AUF2 の XXH3-128 は c5d0f11cd4df2bc79cc612f8e4fb124c。
