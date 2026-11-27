# SYNC_Calendar の配布ファイル

`make_release_zip.bat` は `SYNC_Calendar.auf2` と利用案内・見本画像・ライセンスを `SYNC_Calendar.zip` にまとめ、`SYNC_Calendar.catalog.json` に AUF2 の XXH3-128 を記録します。

- 標準の参照先は `C:\ProgramData\aviutl2\Plugin\SYNC_Calendar` です。
- ハッシュ計算には `xxhsum.exe` を使います。PATH、`Win64\Dependencies\xxHash-0.8.4\xxhsum.exe`、または `-XxhsumPath` で指定できます。[xxHash v0.8.4](https://github.com/Cyan4973/xxHash/releases/tag/v0.8.4)

```bat
setup\make_release_zip.bat
setup\make_release_zip.bat -ReleaseDirectory "D:\Release\SYNC_Calendar" -XxhsumPath "D:\Tools\xxhsum.exe"
```

ZIP を展開すると `SYNC_Calendar` フォルダーに本体と同梱資料が入ります。カタログからの導入と削除は、この専用フォルダー単位で行います。初回の公開バージョンは `v1.0.0` です。
