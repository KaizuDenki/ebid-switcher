#requires -Version 5.1
<#
.SYNOPSIS
  GEPS / JACIC CoreRelay switcher for the two paths confirmed on this PC.
.DESCRIPTION
  Does not read or write certificate files, ebid.properties, registry, startup
  entries, browser settings, or firewall rules. Does not collect a PIN.
  Stops only allowlisted CoreRelay processes in the current Windows session,
  after an explicit idle confirmation. Verifies TCP 9980 ownership by PID,
  executable path, and session. Dynamic WSS ports are not hard-coded.
  -CheckLogin asks the user to test login in the browser; it does not authenticate
  automatically. A reported success is followed by another ownership check.
.EXAMPLE
  .\Switch-Ebid.ps1 IC -CheckLogin
.EXAMPLE
  .\Switch-Ebid.ps1 GEPS
.EXAMPLE
  .\Switch-Ebid.ps1 Status
.NOTES
  Windows PowerShell 5.1 / 64-bit. Live Windows operation is not tested here.
  Exit: 0 = requested checks passed; 1 = switch/ownership failure;
        2 = user cancelled, skipped, or reported a login failure.
  A successful switch alone does not prove certificate authentication works.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('IC', 'GEPS', 'Status')]
    [string]$Mode = 'Status',

    [switch]$CheckLogin,

    [ValidateRange(5, 60)]
    [int]$TimeoutSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$paths = @{
    IC   = 'C:\Program Files (x86)\ebid\CoreRelay\bin\CoreRelay.exe'
    GEPS = 'C:\Program Files\ebid\CoreRelay\bin\CoreRelay.exe'
}
$mutex = $null
$locked = $false
$exitCode = 1

function Get-RelayMode {
    param([AllowNull()][string]$ExecutablePath)
    foreach ($name in @('IC', 'GEPS')) {
        if ($ExecutablePath -ieq $paths[$name]) { return $name }
    }
    return 'Unknown'
}

function Get-PortOwners {
    # Do not silence networking query failures or mistake them for a free port.
    $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop |
        Where-Object { $_.LocalPort -eq 9980 })
    $ownerIds = @($listeners | Select-Object -ExpandProperty OwningProcess -Unique)
    foreach ($ownerId in $ownerIds) {
        $process = Get-Process -Id $ownerId -ErrorAction SilentlyContinue
        if ($null -eq $process) {
            throw "9980の所有プロセスが確認中に終了しました。Statusで再確認してください。PID=$ownerId"
        }
        $executable = $process.Path
        [PSCustomObject]@{
            Mode      = Get-RelayMode $executable
            Port      = 9980
            PID       = $process.Id
            SessionId = $process.SessionId
            Path      = $executable
        }
    }
}

function Show-Owners {
    param([AllowEmptyCollection()][object[]]$Owners)
    if ($Owners.Count -eq 0) {
        Write-Host '9980: 待受なし'
    } else {
        $Owners | Format-List Mode, Port, PID, SessionId, Path | Out-Host
    }
}

function Assert-TargetOwner {
    param([object[]]$Owners, [int]$ExpectedId, [string]$ExpectedPath,
          [int]$ExpectedSession)
    if ($Owners.Count -ne 1) {
        throw '9980の所有プロセスが1つではありません。切替成功とは判定しません。'
    }
    $owner = $Owners[0]
    if ($owner.PID -ne $ExpectedId -or $owner.Path -ine $ExpectedPath -or
        $owner.SessionId -ne $ExpectedSession) {
        Show-Owners $Owners
        throw '9980の所有者が起動した対象と一致しません。PID・Path・Sessionを確認してください。'
    }
}

try {
    if ($env:OS -ne 'Windows_NT') { throw 'このスクリプトはWindows用です。' }
    if (-not [Environment]::Is64BitProcess) {
        throw '64bit版のWindows PowerShellから実行してください。'
    }
    Get-Command Get-NetTCPConnection -ErrorAction Stop | Out-Null
    $sessionId = (Get-Process -Id $PID -ErrorAction Stop).SessionId
    $Mode = $Mode.ToUpperInvariant()

    if ($Mode -eq 'STATUS') {
        Show-Owners @(Get-PortOwners)
        Write-Host '起動中のCoreRelay（停止・変更はしません）:'
        Get-Process -Name CoreRelay -ErrorAction SilentlyContinue |
            Select-Object Id, SessionId, Path | Format-List | Out-Host
        Write-Host '注: この表示だけでは、カード認証・ログインの成功は判定できません。'
        $exitCode = 0
    } else {
        # Serializes switcher invocations in this Windows session.
        $mutex = [System.Threading.Mutex]::new($false, 'Local\EbidSwitcher-9980')
        try { $locked = $mutex.WaitOne(0) }
        catch [System.Threading.AbandonedMutexException] { $locked = $true }
        if (-not $locked) { throw '別のスイッチャーが処理中です。' }

        $target = $paths[$Mode]
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            throw "対象EXEがありません: $target"
        }
        $owners = @(Get-PortOwners)
        foreach ($owner in $owners) {
            if ($owner.Mode -eq 'Unknown' -or $owner.SessionId -ne $sessionId) {
                Show-Owners $owners
                throw '9980は未確認のEXE、または別セッションが使用中です。自動停止しません。'
            }
        }

        $candidates = @(Get-Process -Name CoreRelay -ErrorAction SilentlyContinue |
            Where-Object { $_.SessionId -eq $sessionId })
        foreach ($candidate in $candidates) {
            if ((Get-RelayMode $candidate.Path) -eq 'Unknown') {
                throw "同一セッションにパス未確認のCoreRelayがあります。PID=$($candidate.Id)"
            }
        }
        Write-Host "切替先: $Mode"
        Write-Host "EXE   : $target"
        Write-Host '現在の所有者:'
        Show-Owners $owners
        Write-Host '現在のセッションのGEPS版・JACIC版を終了します。他セッションは停止しません。'
        $answer = Read-Host '入札・署名処理をしておらず、関連タブを閉じたら YES と入力'
        if ($answer.Trim() -ine 'YES') {
            Write-Host '中止しました。プロセスの停止・起動はしていません。'
            $exitCode = 2
        } else {
            foreach ($candidate in $candidates) {
                # Revalidate before stopping; do not kill a reused PID.
                $live = Get-Process -Id $candidate.Id -ErrorAction SilentlyContinue
                if ($null -eq $live) { continue }
                if ($live.SessionId -ne $sessionId -or
                    (Get-RelayMode $live.Path) -eq 'Unknown' -or
                    $live.StartTime -ne $candidate.StartTime) {
                    throw '停止対象が確認時から変わりました。停止を中止します。'
                }
                Write-Host "停止: PID=$($live.Id) $($live.Path)"
                Stop-Process -InputObject $live -Force -ErrorAction Stop
                if (-not $live.WaitForExit($TimeoutSeconds * 1000)) {
                    throw "プロセス終了待ちがタイムアウトしました。PID=$($live.Id)"
                }
            }

            # Wait for the listener to disappear, but never kill a newly started owner.
            $timer = [Diagnostics.Stopwatch]::StartNew()
            do {
                $owners = @(Get-PortOwners)
                if ($owners.Count -eq 0) { break }
                Start-Sleep -Milliseconds 250
            } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
            if ($owners.Count -ne 0) {
                Show-Owners $owners
                throw '9980が解放されません。再起動したアプリ等がないか確認してください。'
            }

            $started = Start-Process -FilePath $target `
                -WorkingDirectory (Split-Path -Parent $target) -PassThru -ErrorAction Stop
            Write-Host "起動: PID=$($started.Id)"
            $timer.Restart()
            $stableAt = $null
            $ready = $false
            do {
                Start-Sleep -Milliseconds 250
                $started.Refresh()
                if ($started.HasExited) {
                    throw "対象EXEが終了しました。終了コード=$($started.ExitCode)"
                }
                $owners = @(Get-PortOwners)
                if ($owners.Count -eq 0) {
                    $stableAt = $null
                    continue
                }
                Assert-TargetOwner $owners $started.Id $target $sessionId
                if ($null -eq $stableAt) { $stableAt = $timer.Elapsed.TotalSeconds }
                if (($timer.Elapsed.TotalSeconds - $stableAt) -ge 1.5) {
                    $ready = $true
                    break
                }
            } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
            if (-not $ready) { throw '対象EXEの9980待受を継続確認できませんでした。' }

            Write-Host "[SWITCH OK] Mode=$Mode / PID=$($started.Id) / Port=9980"
            Show-Owners $owners
            Write-Host 'EXE切替は確認済み。証明書認証は、まだ未確認です。'
            $exitCode = 0

            if ($CheckLogin) {
                if ($Mode -eq 'IC') {
                    Write-Host 'ICカードを接続し、このカードを登録済みのIC対応サイトを開き直してください。'
                    Write-Host 'カードのPINはブラウザ操作で出る正規のダイアログに入力してください。'
                } else {
                    Write-Host '調達ポータルを開き直し、従来のファイル型証明書でログインを確認してください。'
                }
                Write-Host 'ここにはPIN・パスワードを入力しないでください。入札書の提出は不要です。'
                $loginResult = Read-Host 'ログイン後の画面まで進めたら OK、エラーなら NG、未確認なら SKIP'
                # The browser test might have launched or replaced a relay; check again.
                $owners = @(Get-PortOwners)
                Show-Owners $owners
                Assert-TargetOwner $owners $started.Id $target $sessionId
                if ($loginResult.Trim() -ieq 'OK') {
                    Write-Host '[LOGIN REPORTED OK] 利用者がログイン成功を確認。EXE/9980所有者も再確認済み。'
                    $exitCode = 0
                } elseif ($loginResult.Trim() -ieq 'NG') {
                    Write-Host '[LOGIN NOT PASSED] 切替は成功しましたが、利用者がログインエラーを報告しました。'
                    Write-Host '設定は変更しません。エラー番号と、このMode/PID/Pathで切り分けます。'
                    $exitCode = 2
                } else {
                    Write-Host '[LOGIN UNVERIFIED] ログイン成功は確認できていません。'
                    $exitCode = 2
                }
            }
        }
    }
} catch {
    Write-Host ("[ERROR] " + $_.Exception.Message)
    Write-Host '設定の変更や自動復元はしていません。状態の確認: Switch-Ebid.ps1 Status'
    Write-Host 'アクセス拒否の場合は、管理者で起動中のCoreRelayを手動終了し、通常権限でやり直してください。'
    $exitCode = 1
} finally {
    if ($locked -and $null -ne $mutex) { $mutex.ReleaseMutex() }
    if ($null -ne $mutex) { $mutex.Dispose() }
}
exit $exitCode
