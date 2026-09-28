# 生成 Android release 签名密钥（.jks）并自动写出 android/key.properties。
#
# 用法（在 flutter_app 目录下执行）：
#   powershell -ExecutionPolicy Bypass -File tool\gen-keystore.ps1                # 生成密钥
#   powershell -ExecutionPolicy Bypass -File tool\gen-keystore.ps1 -Check         # 校验指纹
#   powershell -ExecutionPolicy Bypass -File tool\gen-keystore.ps1 -Check -Jks <路径>
#   powershell -ExecutionPolicy Bypass -File tool\gen-keystore.ps1 -Force         # 危险：强生成新密钥
#
# 前置：JDK 17+（keytool 在 PATH），或装有 Android Studio（脚本自动找其自带 JBR）。
# 产出：
#   1. %USERPROFILE%\keys\shuyingwengu-release.jks   ← 密钥本体，务必备份到网盘 + U 盘
#   2. android\key.properties                        ← 构建时读取，已被 .gitignore 忽略
#
# ⚠️ 密钥一旦用于上架就不可更换（换密钥 = 用户无法覆盖安装）。
#    密钥文件丢失 = 应用永远无法更新，只能换包名重新上架。
#
# ⚠️ 换机器时**不要**在新机器上跑本脚本重新生成！
#    把 .jks 原样拷过去，然后跑 -Check 验证指纹即可。
#    正确的密钥指纹登记在 tool/keystore-fingerprint.txt。

[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Force,
    [string]$Jks = ''
)

$ErrorActionPreference = 'Stop'

$aliasName = 'shuyingwengu'
$dname     = 'CN=ShuYingWenGu, OU=Personal, O=BookMovie, L=City, S=State, C=CN'
$regFile   = Join-Path $PSScriptRoot 'keystore-fingerprint.txt'

# ── 1. 定位 keytool ─────────────────────────────────────────────
$keytool = $null
if (Get-Command keytool -ErrorAction SilentlyContinue) {
    $keytool = (Get-Command keytool).Source
} else {
    $candidates = @(
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe",
        "$env:ProgramFiles\Java\*\bin\keytool.exe",
        "$env:ProgramFiles\Eclipse Adoptium\*\bin\keytool.exe"
    )
    foreach ($c in $candidates) {
        $hit = Resolve-Path $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { $keytool = $hit.Path; break }
    }
}
if (-not $keytool) {
    Write-Host '[错误] 未找到 keytool。' -ForegroundColor Red
    Write-Host '请先安装 JDK 17+（winget install EclipseAdoptium.Temurin.17.JDK）或 Android Studio。'
    exit 1
}

# ── 2. 工具函数 ─────────────────────────────────────────────────
function Get-RegValue {
    param([string]$Key)
    if (-not (Test-Path $regFile)) { return $null }
    $line = Select-String -Path $regFile -Pattern "^$Key=" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Line -replace "^$Key=", '').Trim()
}

# 字节数组 → 大写十六进制（冒号分隔）
function ConvertTo-HexString {
    param([byte[]]$Bytes)
    return (($Bytes | ForEach-Object { $_.ToString('x2').ToUpper() }) -join ':')
}

# 用临时 p12 + .NET 读证书，返回 指纹 / 公钥 / 主体
function Get-CertInfo {
    param([string]$Keystore, [string]$Pass)

    $tmpP12 = Join-Path $env:TEMP ("kt_" + [guid]::NewGuid().ToString('N') + ".p12")
    # keytool 会往 stderr 写日志，Stop 模式下会被当成异常终止，这里临时降级
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $keytool -importkeystore -noprompt `
        -srckeystore $Keystore -destkeystore $tmpP12 -deststoretype PKCS12 `
        -srcstorepass $Pass -deststorepass $Pass 2>&1 | Out-Null
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($exit -ne 0 -or -not (Test-Path $tmpP12)) { return $null }

    try {
        $pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $pfx.Import($tmpP12, $Pass, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
    } catch {
        Remove-Item $tmpP12 -Force -ErrorAction SilentlyContinue
        return $null
    }
    Remove-Item $tmpP12 -Force -ErrorAction SilentlyContinue

    $raw = $pfx.RawData
    return [pscustomobject]@{
        MD5      = ConvertTo-HexString ([System.Security.Cryptography.MD5]::Create().ComputeHash($raw))
        SHA1     = ConvertTo-HexString ([System.Security.Cryptography.SHA1]::Create().ComputeHash($raw))
        SHA256   = ConvertTo-HexString ([System.Security.Cryptography.SHA256]::Create().ComputeHash($raw))
        PubKey   = [BitConverter]::ToString($pfx.PublicKey.EncodedKeyValue.RawData) -replace '-', ''
        Subject  = $pfx.Subject
        NotAfter = $pfx.NotAfter
    }
}

# 写出 android\key.properties（android\ 存在时才写，避免被 flutter create 清掉）
function Write-KeyProperties {
    param([string]$Keystore, [string]$Pass)
    $androidDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'android'
    if (-not (Test-Path $androidDir)) {
        Write-Host '==> 跳过 key.properties：android\ 目录还不存在（跑完 flutter create 后再说）'
        return
    }
    $jksForProps = $Keystore -replace '\\', '/'
    $props = "storePassword=$Pass`nkeyPassword=$Pass`nkeyAlias=$aliasName`nstoreFile=$jksForProps`n"
    [System.IO.File]::WriteAllText((Join-Path $androidDir 'key.properties'), $props)
    Write-Host '==> 已写出 android\key.properties'
}

function Get-KeystorePass {
    $props = Join-Path (Split-Path $PSScriptRoot -Parent) 'android\key.properties'
    if (Test-Path $props) {
        $line = Select-String -Path $props -Pattern '^storePassword=' | Select-Object -First 1
        if ($line) { return ($line.Line -replace '^storePassword=', '').Trim() }
    }
    $secure = Read-Host '请输入 keystore 密码（不回显）' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    return $plain
}

$keysDir = Join-Path $env:USERPROFILE 'keys'
if (-not $Jks) { $Jks = Join-Path $keysDir "$aliasName-release.jks" }
$regMd5 = Get-RegValue 'MD5'

# ── 3. 校验模式 ─────────────────────────────────────────────────
if ($Check) {
    Write-Host "==> 校验模式：$Jks"
    if (-not (Test-Path $Jks)) {
        Write-Host "[错误] 文件不存在：$Jks" -ForegroundColor Red
        Write-Host '       换机器时请先把原机器上的 .jks 拷到 %USERPROFILE%\keys\。'
        exit 1
    }
    $pass = Get-KeystorePass
    $info = Get-CertInfo -Keystore $Jks -Pass $pass
    if (-not $info) { Write-Host '[错误] 读取证书失败（密码错？）' -ForegroundColor Red; exit 1 }

    Write-Host "  MD5    : $($info.MD5)"
    Write-Host "  SHA1   : $($info.SHA1)"
    Write-Host "  SHA256 : $($info.SHA256)"
    Write-Host "  登记表 :"
    Write-Host "  MD5    : $(Get-RegValue 'MD5')"
    Write-Host "  SHA1   : $(Get-RegValue 'SHA1')"
    Write-Host "  SHA256 : $(Get-RegValue 'SHA256')"
    Write-Host ''
    $ok = ($info.MD5 -eq (Get-RegValue 'MD5'))
    if ($ok) {
        Write-Host '✅ 一致：这份 .jks 就是本项目的正式密钥，可放心用于构建与备案。' -ForegroundColor Green
        Write-KeyProperties -Keystore $Jks -Pass $pass
        exit 0
    } else {
        Write-Host '❌ 不一致！这份 .jks 不是本项目的正式密钥。' -ForegroundColor Red
        Write-Host '   千万不要用它构建上架包：备案信息对不上、老用户无法覆盖安装。' -ForegroundColor Red
        Write-Host '   请从备份（网盘 / U 盘）取回正确的那一份。' -ForegroundColor Red
        exit 1
    }
}

# ── 4. 生成模式：防误生成拦截 ───────────────────────────────────
if (Test-Path $Jks) {
    Write-Host "==> 检测到已存在的密钥：$Jks"
    try {
        $passNow = Get-KeystorePass
        $infoNow = Get-CertInfo -Keystore $Jks -Pass $passNow
        if ($infoNow -and $regMd5 -and $infoNow.MD5 -eq $regMd5) {
            Write-Host '✅ 指纹与登记表一致 —— 这就是本项目的正式密钥，无需重新生成。' -ForegroundColor Green
            Write-Host '   直接用它构建即可。'
            Write-KeyProperties -Keystore $Jks -Pass $passNow
            exit 0
        }
    } catch { }
    $ans = Read-Host '[警告] 覆盖已有密钥将导致无法更新已上架应用！确认覆盖？(y/N)'
    if ($ans -notmatch '^[Yy]') { Write-Host '已取消。'; exit 0 }
    Remove-Item $Jks -Force
} elseif ($regMd5 -and -not $Force) {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Red
    Write-Host '║  ⛔ 停下！本机没有密钥，但本项目已有一份正式密钥的登记记录：║' -ForegroundColor Red
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Red
    Write-Host ''
    Write-Host "  登记表：tool\keystore-fingerprint.txt"
    Write-Host "  别名  ：$aliasName"
    Write-Host "  MD5   ：$regMd5"
    Write-Host ''
    Write-Host '  这意味着正式密钥已经生成过了（在生成它的那台机器上）。'
    Write-Host '  在另一台机器上跑本脚本会得到一份全新的、不同的密钥，后果：'
    Write-Host '    · 用新密钥签名的 APK 无法覆盖安装老版本（签名不一致）'
    Write-Host '    · 备案时填的证书指纹与实际上架包不符，需要走变更备案'
    Write-Host '    · 已上架的 App 永远无法更新 —— 只能换包名重新上架'
    Write-Host ''
    Write-Host '  ✅ 正确做法：把原机器上的 .jks 拷到本机 %USERPROFILE%\keys\，然后执行：' -ForegroundColor Green
    Write-Host '     powershell -ExecutionPolicy Bypass -File tool\gen-keystore.ps1 -Check' -ForegroundColor Green
    Write-Host ''
    $ans = Read-Host '如果你确定要生成全新密钥，请输入 GENERATE-NEW-KEY 确认'
    if ($ans -ne 'GENERATE-NEW-KEY') { Write-Host '已取消。'; exit 0 }
}

# ── 5. 设置密码 ─────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $keysDir | Out-Null
$secure = Read-Host '请设置 keystore 密码（至少 6 位，输入不回显）' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$storePass = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
if ($storePass.Length -lt 6) { Write-Host '[错误] 密码至少 6 位。' -ForegroundColor Red; exit 1 }
$secure2 = Read-Host '请再输入一次确认' -AsSecureString
$bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure2)
$storePass2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
if ($storePass -ne $storePass2) { Write-Host '[错误] 两次输入不一致。' -ForegroundColor Red; exit 1 }

# ── 6. 生成密钥 ─────────────────────────────────────────────────
Write-Host "[1/4] 生成密钥：$Jks"
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'   # keytool 的 stderr 日志在 Stop 模式下会被当成异常
& $keytool -genkeypair -v `
    -keystore $Jks `
    -alias $aliasName `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -storepass $storePass -keypass $storePass `
    -dname $dname
$exit = $LASTEXITCODE
$ErrorActionPreference = $prev
if ($exit -ne 0 -or -not (Test-Path $Jks)) {
    Write-Host '[错误] keytool 生成失败。' -ForegroundColor Red; exit 1
}
Write-Host '[2/4] 密钥已生成'

# ── 7. 写出 android/key.properties ──────────────────────────────
Write-KeyProperties -Keystore $Jks -Pass $storePass

# ── 8. 打印指纹 ─────────────────────────────────────────────────
Write-Host '[4/4] 完成！证书指纹：'
$info = Get-CertInfo -Keystore $Jks -Pass $storePass
if ($info) {
    Write-Host "  MD5    : $($info.MD5)"
    Write-Host "  SHA1   : $($info.SHA1)"
    Write-Host "  SHA256 : $($info.SHA256)"
    Write-Host "  公钥   : $($info.PubKey)"
    Write-Host "  到期   : $($info.NotAfter.ToString('yyyy-MM-dd'))"
    if ($regMd5) {
        Write-Host ''
        if ($info.MD5 -eq $regMd5) { Write-Host "  与登记表一致。" -ForegroundColor Green }
        else { Write-Host "  ⚠️ 登记表 MD5 是 $regMd5，与本次不一致 —— 刚生成的是新密钥，请更新登记表与备案信息！" -ForegroundColor Red }
    }
}

Write-Host ''
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host "  密钥文件：$Jks"
Write-Host '  请立即备份到网盘 + U 盘（至少两处异地）！'
Write-Host '  丢失密钥 = 应用永远无法更新，只能换包名重新上架。'
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host ''
Write-Host '换机器后请执行（验证拷过来的密钥是对的）：'
Write-Host '  powershell -ExecutionPolicy Bypass -File tool\gen-keystore.ps1 -Check'
Write-Host '下一步：'
Write-Host '  flutter build apk --release --split-per-abi   # 出正式签名 APK'
Write-Host '  keytool -printcert -jarfile <apk路径>          # 验证签名（备案时要填 MD5）'
