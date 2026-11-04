# Builds the portable Windows package: Monorail.exe plus every DLL it loads that Windows itself
# doesn't have, in Monorail-Windows-portable\, zipped as Monorail-Windows-portable.zip.
# No installer, no admin: unzip and run. Run from the repository root on Windows, after
# `swift build -c release --product MonorailWindows`, in PowerShell 7 (CI: .github/workflows/platforms.yml).
#
# The DLL list isn't guessed: dumpbin reads each file's imports, starting from the exe, and every
# DLL that comes from the Swift toolchain or runtime (found on PATH outside Windows' folders) is
# copied and read in turn. The Visual C++ runtime DLLs are copied too, from Visual Studio's
# redistributable folder, so a PC without the VC++ redistributable can still run it.
param(
    [string]$Exe = ".build\release\MonorailWindows.exe",
    [string]$Out = "Monorail-Windows-portable"
)
$ErrorActionPreference = "Stop"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$dumpbin = Get-ChildItem "$vs\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe" | Sort-Object FullName | Select-Object -Last 1
if (-not $dumpbin) { throw "dumpbin.exe not found under $vs" }
$redist = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -Directory -ErrorAction SilentlyContinue |
    Sort-Object FullName | Select-Object -Last 1
Write-Host "dumpbin: $($dumpbin.FullName)"
Write-Host "VC++ redistributable: $($redist.FullName)"

$windowsDir = $env:SystemRoot.TrimEnd('\')
$searchDirs = $env:Path -split ';' | Where-Object { $_ -and (Test-Path $_) } |
    Where-Object { -not $_.TrimEnd('\').StartsWith($windowsDir, [StringComparison]::OrdinalIgnoreCase) } |
    Select-Object -Unique
$vcRuntime = '^(vcruntime140(_1)?|msvcp140(_1|_2|_atomic_wait|_codecvt_ids)?|concrt140|vccorlib140)\.dll$'

function Get-Imports([string]$file) {
    $lines = & $dumpbin.FullName /nologo /dependents $file
    if ($LASTEXITCODE -ne 0) { throw "dumpbin failed on $file" }
    $lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[\w\-\.]+\.dll$' }
}

function Find-Dll([string]$name) {
    foreach ($dir in $searchDirs) {
        $candidate = Join-Path $dir $name
        if (Test-Path $candidate -PathType Leaf) { return (Get-Item $candidate) }
    }
    return $null
}

Remove-Item $Out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $Out | Out-Null
Copy-Item $Exe (Join-Path $Out "Monorail.exe")

$bundled = [ordered]@{}
$system = [System.Collections.Generic.SortedSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue((Resolve-Path $Exe).Path)
while ($queue.Count -gt 0) {
    $file = $queue.Dequeue()
    foreach ($dll in Get-Imports $file) {
        $key = $dll.ToLowerInvariant()
        if ($bundled.Contains($key) -or $system.Contains($dll)) { continue }
        if ($dll -match $vcRuntime) {
            $source = if ($redist) { Get-Item (Join-Path $redist.FullName $dll) -ErrorAction SilentlyContinue }
            if (-not $source) { $source = Get-Item "$windowsDir\System32\$dll" }
            $bundled[$key] = $source.FullName
            $queue.Enqueue($source.FullName)
            continue
        }
        if ($dll -match '^(api|ext)-ms-' -or (Test-Path "$windowsDir\System32\$dll")) { [void]$system.Add($dll); continue }
        $found = Find-Dll $dll
        if (-not $found) { throw "$file imports $dll, which is neither part of Windows nor found on PATH" }
        $bundled[$key] = $found.FullName
        $queue.Enqueue($found.FullName)
    }
}

foreach ($source in $bundled.Values) { Copy-Item $source $Out }
$version = (Get-Content VERSION -Raw).Trim()
(Get-Content windows\portable\README.txt -Raw).Replace("{VERSION}", $version).Replace("`r`n", "`n").Replace("`n", "`r`n") |
    Set-Content (Join-Path $Out "README.txt") -NoNewline -Encoding utf8
Copy-Item LICENSE (Join-Path $Out "LICENSE.txt")

Write-Host "`nBundled DLLs (from the Swift toolchain and runtime, and the VC++ runtime):"
$bundled.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-40} {1}" -f (Split-Path $_.Value -Leaf), $_.Value) }
Write-Host "`nLeft to Windows (part of every Windows 10 and 11):"
$system | ForEach-Object { Write-Host "  $_" }
(@($bundled.Values) | ForEach-Object { Split-Path $_ -Leaf }) | Sort-Object | Set-Content "$Out-dlls.txt"

Remove-Item "$Out.zip" -ErrorAction SilentlyContinue
Compress-Archive -Path $Out -DestinationPath "$Out.zip"
Write-Host "`n$Out.zip:"
Get-ChildItem $Out | ForEach-Object { Write-Host ("  {0,-40} {1,10:N0} bytes" -f $_.Name, $_.Length) }
