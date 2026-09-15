電子入札 CoreRelay スイッチャー
作成日: 2026-09-15

目的
GEPS版とJACIC/e-Probatio版を排他的に起動し、TCP 9980の所有者を
起動したPID・実行ファイルのフルパス・Windowsセッションと照合します。
このPCで確認された以下のパス専用です。

GEPS: C:\Program Files\ebid\CoreRelay\bin\CoreRelay.exe
IC:   C:\Program Files (x86)\ebid\CoreRelay\bin\CoreRelay.exe

前提
・先に作成したGEPS側bin\ebid.propertiesを残します。
・共有設定がe-Probatioを指したままである前提です。
・スクリプトは設定ファイル、証明書、レジストリ、スタートアップ、
  ブラウザ設定、ファイアウォールに書き込みません。
・GEPSのファイル型動作は利用者が確認済み。IC側への切戻しは今回確認します。
・Windows実機での本スクリプトの起動・停止・認証は未検証です。
・PINや秘密鍵を読み取り、保存、送信する機能はありません。

最初のIC動作確認
1. ZIPをWindowsの任意のフォルダーに展開し、ファイルを同じ場所に置きます。
2. 入札書等を編集中・署名中・送信中でないことを確認し、関連タブを閉じます。
3. 01-IC-Check.cmdを通常権限でダブルクリックします。
4. 確認を読んでYESと入力すると、現在のセッションの確認済みCoreRelayを
   強制終了し、IC版を起動します。別セッションのアプリは停止しません。
5. [SWITCH OK]、Mode=IC、PathがProgram Files (x86)側であることを確認します。
6. ICカードをリーダーに挿し、そのカードを登録済みのIC対応サイトを新しく開きます。
   GEPSのファイル型ログイン画面をIC動作確認の代わりに使わないでください。
7. カードPINは正規のダイアログに入力します。PowerShellには入力しません。
   ログイン後の画面まで確認します。入札書の提出などは行う必要がありません。
8. PowerShellへ戻り、成功ならOK、エラーならNG、未確認ならSKIPと入力します。
9. スクリプトはログイン操作後に9980所有者を再確認します。
   [LOGIN REPORTED OK]は利用者の成功申告＋所有確認であり、認証の自動判定ではありません。

普段の切替
IC.cmd       IC側に切替し、EXE/PID/9980所有者を確認
GEPS.cmd     GEPS側に切替し、EXE/PID/9980所有者を確認
Status.cmd   現在の9980所有者とCoreRelay一覧を表示。変更なし

PowerShellから実行
スクリプトを配置したフォルダーで、必要な行だけ実行します。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Switch-Ebid.ps1 IC -CheckLogin
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Switch-Ebid.ps1 IC
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Switch-Ebid.ps1 GEPS
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Switch-Ebid.ps1 Status

ExecutionPolicy Bypassについて
付属cmdはスクリプトを呼び出すPowerShellプロセスにだけBypassを指定します。
Set-ExecutionPolicyは使わず、PCやユーザーの永続的な実行ポリシーは変更しません。
組織のグループポリシーにより実行できない場合は、管理方針に従ってください。

エラー時
・[SWITCH OK]とログイン成功は別です。10051等が出たらNGと入力してください。
・切替後に開くサイト、エラー番号、直後のMode/PID/Pathを確認します。
・未知のプロセス、別セッションが9980を使用中なら、自動では停止しません。
・アクセス拒否の場合は、管理者で起動している既存CoreRelayを手動で終了し、
  その後は通常権限のcmdから切替をやり直してください。自動昇格はしません。
・途中失敗時に元のEXEを自動で再起動する機能はありません。まずStatusで確認します。
・このスクリプトは常駐しません。後から別アプリが起動した場合はStatusで再確認します。
・サポートによる同一端末での併用保証を示すものではありません。

実装の確認資料（Microsoft公式）
https://learn.microsoft.com/powershell/module/microsoft.powershell.management/start-process
https://learn.microsoft.com/powershell/module/microsoft.powershell.management/stop-process
https://learn.microsoft.com/powershell/module/nettcpip/get-nettcpconnection
https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies
