# PowerShell helper script: Sync latest index.html & push github_deploy to GitHub
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$DeployDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $DeployDir
$SourceHtml = Join-Path $RootDir "dashboard_app\index.html"
$TargetHtml = Join-Path $DeployDir "index.html"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  GitHub Pages Deploy Helper - Population Audit Dashboard"   -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Sync latest dashboard index.html
if (Test-Path $SourceHtml) {
    Copy-Item -Path $SourceHtml -Destination $TargetHtml -Force
    $sizeKB = [math]::Round((Get-Item $TargetHtml).Length / 1KB, 1)
    Write-Host "[OK] อัปเดตไฟล์ index.html ล่าสุดเรียบร้อยแล้ว ($sizeKB KB)" -ForegroundColor Green
} else {
    Write-Host "[WARN] ไม่พบไฟล์ต้นทาง dashboard_app\index.html ใช้ไฟล์เดิมใน github_deploy" -ForegroundColor Yellow
}

# 2. Locate Git
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    $candidates = @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $gitCmd = $c; break }
    }
} else {
    $gitCmd = $gitCmd.Source
}

if (-not $gitCmd) {
    Write-Host ""
    Write-Host "[!] ยังไม่ได้ติดตั้ง Git ในเครื่องนี้" -ForegroundColor Red
    Write-Host "    วิธีติดตั้ง:" -ForegroundColor Yellow
    Write-Host "    1) ดาวน์โหลดฟรีจาก https://git-scm.com/download/win (กด Next ไปเรื่อยๆ จนเสร็จ)"
    Write-Host "    2) หรือเปิด PowerShell แล้วพิมพ์: winget install --id Git.Git -e"
    Write-Host "    3) หลังติดตั้งเสร็จ กลับมาดับเบิลคลิกไฟล์ publish_github.bat นี้อีกครั้งครับ"
    Write-Host ""
    Read-Host "กด Enter เพื่อปิดหน้าต่าง"
    exit 1
}

Write-Host "[OK] พบโปรแกรม Git: $gitCmd" -ForegroundColor Green
Set-Location $DeployDir

# 3. Initialize git repository if needed
if (-not (Test-Path (Join-Path $DeployDir ".git"))) {
    Write-Host "[...] กำลังตั้งค่า Git Repository ใหม่ในโฟลเดอร์ github_deploy..." -ForegroundColor Cyan
    & $gitCmd init
    & $gitCmd branch -M main
}

# 4. Check Git user.name & user.email
$userName = (& $gitCmd config user.name 2>$null)
$userEmail = (& $gitCmd config user.email 2>$null)

if (-not $userName) {
    Write-Host ""
    $userName = Read-Host "กรอกชื่อผู้ใช้ GitHub ของคุณ (เช่น MonStat)"
    if ($userName) { & $gitCmd config --global user.name "$userName" }
}
if (-not $userEmail) {
    $userEmail = Read-Host "กรอกอีเมลที่ใช้สมัคร GitHub ของคุณ"
    if ($userEmail) { & $gitCmd config --global user.email "$userEmail" }
}

# 5. Check remote origin URL
$remoteUrl = (& $gitCmd remote get-url origin 2>$null)
if (-not $remoteUrl) {
    Write-Host ""
    Write-Host "กรุณาวางลิงก์ GitHub Repository ของคุณ" -ForegroundColor Yellow
    Write-Host "ตัวอย่าง: https://github.com/username/population-dashboard-thailand.git" -ForegroundColor Gray
    $remoteUrl = Read-Host "GitHub Repo URL"
    if (-not $remoteUrl) {
        Write-Host "[!] ยกเลิกการอัปโหลด เนื่องจากยังไม่ได้ระบุลิงก์ Repository" -ForegroundColor Red
        Read-Host "กด Enter เพื่อปิดหน้าต่าง"
        exit 1
    }
    & $gitCmd remote add origin "$remoteUrl"
}

Write-Host "[OK] เชื่อมต่อปลายทาง: $remoteUrl" -ForegroundColor Green

# 6. Stage, commit, and push (exclude helper scripts from public web repo if desired, or keep clean)
& $gitCmd add index.html README.md .gitignore .nojekyll

$status = & $gitCmd status --porcelain
if ($status) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    & $gitCmd commit -m "Update population dashboard ($timestamp)"
} else {
    Write-Host "[INFO] ไม่มีการเปลี่ยนแปลงใหม่ตั้งแต่การอัปโหลดครั้งล่าสุด" -ForegroundColor Yellow
}

Write-Host "[...] กำลังอัปโหลด (Push) ขึ้น GitHub..." -ForegroundColor Cyan
Write-Host "      (หากอัปโหลดครั้งแรก จะมีหน้าต่างให้กด Sign in with your browser)" -ForegroundColor Gray
& $gitCmd push -u origin main

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  อัปโหลดขึ้น GitHub เสร็จสมบูรณ์!" -ForegroundColor Green
Write-Host "  เปิดใช้งานเว็บ: ไปที่ Settings -> Pages -> Branch: main" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Read-Host "กด Enter เพื่อปิดหน้าต่าง"
