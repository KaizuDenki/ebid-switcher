# 電子入札 CoreRelay スイッチャー

調達ポータル・政府電子調達（GEPS）のファイル型電子証明書と、自治体電子入札のICカードを同一Windows端末で使い分けるための切替ツール＆設定分離ガイドです。

本ツールは、カイズ電気株式会社の環境（ICカード側：**e-Probatio PS2 ＋ JACIC系電子入札補助アプリ**）で発生した競合トラブルへの対処として作成されたPowerShell製スクリプトです。

> **※注意**
> 本ツールは特定の環境で動作を確認した**非公式の回避策**です。あらゆる調達サイト・認証局・ICカードに対応する汎用ツールではなく、両アプリの同時起動を可能にするものでもありません。

- **公開先**: `KaizuDenki/ebid-switcher`

- **提供**: カイズ電気株式会社

- **ライセンス**: [MIT](https://www.google.com/search?q=LICENSE)

---

## 背景・開発経緯

当社では、国の調達ポータル（GEPS）に「ファイル型電子証明書」、自治体の電子入札に「ICカード（e-Probatio PS2）」を使用しており、入札先に応じてこれらを使い分ける必要がありました。

しかし、ICカード利用ソフトの導入後、GEPSでファイル型証明書を使おうとすると「ポート9980の通信失敗」「デバイス使用不可」等のエラーが発生。起動アプリの切り替えだけでは解消せず、調査したところ**2つの異なる競合**が判明しました。

1. **通信ポートの競合**: GEPS版とICカード側の双方の `CoreRelay.exe` が同じ TCP 9980 ポートを要求するため同時起動できない。

2. **証明書処理設定の競合**: `ProgramData` 配下の共有 `ebid.properties` がICカード用DLL（e-Probatio）を指定しているため、GEPS版起動時にもICカード用設定が適用されてしまう。

そこで、検証により判明した「GEPS版は同フォルダー内の `ebid.properties` を優先読み込みする」仕様を利用し、**ICカード側の共有設定は変更せず、GEPS側のみ専用設定に分離**する対処を行いました。

> **重要**: 初回の設定分離と日常のEXE切替は別の作業です。本スイッチャーを実行するだけでは共有設定の競合は解消しません。あらかじめ[設定分離の手順](https://www.google.com/search?q=docs/config-isolation.md)を実施してください。

---

## 競合と対処のまとめ

| 競合要素                  | 確認された現象                              | 対処法 |
| ------------------------- | ------------------------------------------- | ------ |
| **通信ポート (TCP 9980)** | GEPS版とICカード側の `CoreRelay.exe` が衝突 |

| 利用する側だけを排他的に起動

|
| **証明書処理設定** | 共有 `ebid.properties` のICカード用DLL指定が優先される

| GEPSフォルダーに専用 `ebid.properties` を作成し、`MicP12Wrapper.dll` を指定

|

---

## 対象環境・前提条件

本ツールは以下の固定パスにある実行ファイルを対象とします。

| 用途                         | 実行ファイル                                                  | 確認済み FileVersion |
| ---------------------------- | ------------------------------------------------------------- | -------------------- |
| **GEPS（ファイル型証明書）** | `C:\Program Files\ebid\CoreRelay\bin\CoreRelay.exe`<br>       | `1.4.0.0`<br>        |
| **自治体（ICカード）**       | `C:\Program Files (x86)\ebid\CoreRelay\bin\CoreRelay.exe`<br> | `1.4.0.0`<br>        |

### 実行要件

- 64bit OS上の Windows PowerShell 5.1 以降（`Get-NetTCPConnection` コマンドレットが利用可能であること）

### 利用の前提

- 公式ソフト、証明書、ICカード、カードリーダーの導入および利用先への登録が完了していること（本ツールはこれらを導入・登録しません）。

- 事前に[初回の設定分離](https://www.google.com/search?q=docs/config-isolation.md)が完了していること。

- 同一Windowsセッション内で順番に切り替えて利用すること（複数ユーザー・RDPセッション間の同時利用調整には非対応）。

---

## セットアップと初回確認

1. **[設定分離の手順](https://www.google.com/search?q=docs/config-isolation.md)の実施**: GEPS用の専用設定を作成します。

2. **ファイルの配置**: リポジトリをダウンロード・解凍し、`.cmd` と `Switch-Ebid.ps1` を同一フォルダーに配置します。

3. **動作確認**: `01-IC-Check.cmd` および `02-GEPS-Check.cmd` を実行し、それぞれの切替と実際のログインを確認します。

- ※初回設定（ファイル作成等）には管理者権限が必要です。

- ※日常の切替（スイッチャー実行）は**通常権限**で行ってください。

---

## 日常の使い方

> **注意**: 入札書の編集・署名・送信中には切り替えないでください。必ずブラウザーの関連タブを閉じてから実行してください。

### 付属ランチャー（`.cmd`）一覧

| ファイル名 | 処理内容                                       |
| ---------- | ---------------------------------------------- |
| `IC.cmd`   | ICカード側に切り替え、TCP 9980の占有状況を確認 |

|
| `GEPS.cmd` | GEPS（ファイル型）側に切り替え、TCP 9980の占有状況を確認

|
| `Status.cmd` | 現在のポート所有者と `CoreRelay` の起動状態を表示（停止・起動は行わない）

|
| `01-IC-Check.cmd` | IC側に切り替え、手動ログイン確認後に占有状態を再確認

|
| `02-GEPS-Check.cmd` | GEPS側に切り替え、手動ログイン確認後に占有状態を再確認

|

### PowerShellからの実行

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Switch-Ebid.ps1 IC -CheckLogin
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Switch-Ebid.ps1 GEPS -CheckLogin
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Switch-Ebid.ps1 Status

```

- `-CheckLogin` 指定時は、ブラウザーでログイン確認後、コマンドラインに `OK` / `NG` / `SKIP` を入力します。

- PINやパスワードはPowerShell上には入力せず、必ず公式アプリのダイアログに入力してください。

---

## スイッチャーの仕様（行うこと・行わないこと）

### 行うこと

- 既存の対象 `CoreRelay.exe` を排他的に停止・起動する。

- TCP 9980 ポートの所有PID・実行パス・セッションIDの一致を確認する。

### 行わないこと

- 証明書、PIN、秘密鍵、Cookie等の情報読み取り・保存。

- 設定ファイル、レジストリ、ブラウザー設定、ファイアウォール規則等の自動変更。

- トラブル時の自動修復、常駐監視、macOSへの対応。

---

## 動作確認状況・免責事項

- **確認日**: 2026年9月15日

- **確認環境**: 当社社内の特定1環境（GEPSファイル型 ＆ e-Probatio PS2 ICカード型）

本ツールは各製品・サービスの公式ソフトウェアではなく、動作や入札業務の継続を保証するものではありません。公式ソフトのアップデートや環境変更により動作しなくなる可能性があります。入札締切直前の導入は避け、必ず事前にバックアップをとった上でご活用ください。

---

## ライセンス・関連リンク

- **ライセンス**: [MIT License](https://www.google.com/search?q=LICENSE)

- [設定分離の手順](https://www.google.com/search?q=docs/config-isolation.md)

- [動作確認記録](https://www.google.com/search?q=docs/verification.md)

- [トラブルシューティング](https://www.google.com/search?q=docs/troubleshooting.md)

- [セキュリティ・情報の取扱い](SECURITY.md)
