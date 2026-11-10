
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$mingw = "C:\msys64\mingw64"
$bin = Join-Path $mingw "bin"

$build = Join-Path $root "build\Desktop_Qt_6_11_1_MinGW_64_bit_Release"
$portable = Join-Path $root "for_release\PORTABLE"

$deploy = Join-Path $bin "windeployqt.exe"
$objdump = Join-Path $bin "objdump.exe"

# 1. Prepare clean directory
Write-Host "Preparing PORTABLE..." -ForegroundColor Cyan

if (Test-Path $portable) {
    Remove-Item $portable -Recurse -Force
}

New-Item -ItemType Directory -Path $portable | Out-Null

# 2. Copy Vexa.exe
$exe = Join-Path $build "Vexa.exe"

if (-not (Test-Path $exe)) {
    throw "Vexa.exe not found: $exe"
}

Copy-Item $exe (Join-Path $portable "Vexa.exe") -Force

# 3. Deploy Qt libraries and QML
Write-Host "Deploying Qt..." -ForegroundColor Cyan

$env:PATH = "$bin;$mingw\share\qt6\bin;$env:PATH"

& $deploy `
    --release `
    --no-translations `
    --qmldir $root `
    "$portable\Vexa.exe"

if ($LASTEXITCODE -ne 0) {
    throw "windeployqt failed"
}

# 4. Remove unused SQL drivers
# Vexa uses Qt SQL with SQLite.
# Keep Qt6Sql.dll and qsqlite.dll.

$sqlDrivers = Join-Path $portable "sqldrivers"

if (-not (Test-Path "$sqlDrivers\qsqlite.dll")) {
    throw "SQLite driver qsqlite.dll not found"
}

Get-ChildItem $sqlDrivers -Filter "*.dll" |
    Where-Object { $_.Name -ne "qsqlite.dll" } |
    ForEach-Object {
        Write-Host "Removing unused SQL driver: $($_.Name)"
        Remove-Item $_.FullName -Force
    }

# 5. Configure Qt paths
@"
[Paths]
Prefix=.
Plugins=.
QmlImports=qml
"@ | Set-Content "$portable\qt.conf" -Encoding ascii

# 6. Resolve DLL dependencies recursively
Write-Host "Resolving dependencies..." -ForegroundColor Cyan

$checked = @{}
$missing = @{}

do {
    $copied = 0

    $files = @(
        Get-Item "$portable\Vexa.exe"
        Get-ChildItem $portable -Recurse -Filter "*.dll"
    )

    foreach ($file in $files) {
        if ($checked.ContainsKey($file.FullName)) {
            continue
        }

        $checked[$file.FullName] = $true

        $output = & $objdump -p $file.FullName 2>$null

        foreach ($line in $output) {
            if ($line -notmatch 'DLL Name:\s*(\S+)') {
                continue
            }

            $dll = $Matches[1]

            # Windows API-set libraries
            if ($dll -match '^(api-ms-|ext-ms-)') {
                continue
            }

            # Check local and Windows system directories
            $paths = @(
                (Join-Path $portable $dll)
                (Join-Path $file.DirectoryName $dll)
                (Join-Path $env:WINDIR "System32\$dll")
                (Join-Path $env:WINDIR "SysWOW64\$dll")
            )

            $found = @(
                $paths | Where-Object { Test-Path $_ }
            ).Count -gt 0

            if ($found) {
                continue
            }

            $source = Join-Path $bin $dll

            if (Test-Path $source) {
                Copy-Item $source $portable -Force

                Write-Host "+ $dll" -ForegroundColor Green

                $copied++
                [void]$missing.Remove($dll)
            }
            else {
                $missing[$dll] = $true
            }
        }
    }
} while ($copied -gt 0)

# 7. Report
Write-Host ""
Write-Host "Deployment complete." -ForegroundColor Cyan

if ($missing.Count -gt 0) {
    Write-Warning "Unresolved dependencies:"

    $missing.Keys |
        Sort-Object |
        ForEach-Object {
            Write-Host "  $_" -ForegroundColor Yellow
        }

    throw "Deployment has unresolved dependencies"
}
else {
    Write-Host "All discovered DLL dependencies resolved." -ForegroundColor Green
}

Write-Host "PORTABLE: $portable" -ForegroundColor Cyan


# 8. Build Inno Setup installer
Write-Host "`nBuilding Vexa installer..." -ForegroundColor Cyan

$inno = "D:\Inno Setup 6\ISCC.exe"
$iss = Join-Path $root "Vexa.iss"

if (-not (Test-Path $inno)) {
    throw "Inno Setup compiler not found: $inno"
}

if (-not (Test-Path $iss)) {
    throw "Installer script not found: $iss"
}

& $inno $iss

if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed"
}

Write-Host "`nVexa installer built successfully." -ForegroundColor Green
Write-Host "Output: $(Join-Path $root 'for_release')" -ForegroundColor Cyan


