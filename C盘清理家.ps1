#requires -Version 5.1
<#
.SYNOPSIS
    安全清理 Windows 临时文件、Windows Update 下载缓存和回收站。
.DESCRIPTION
    脚本仅操作固定白名单路径。默认先扫描并展示统计信息，只有用户明确输入 CLEAN
    后才执行删除。Windows Update 仅清理可重新下载的 Download 目录，不触碰
    DataStore、WinSxS、注册表或用户文档。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SafeChildren {
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
    # 只枚举白名单根目录的第一层；删除时使用 LiteralPath，避免通配符和路径注入。
    return @(Get-ChildItem -LiteralPath $Root -Force -ErrorAction SilentlyContinue)
}

function Get-TreeSummary {
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return [pscustomobject]@{ Files = 0; Bytes = 0L }
    }

    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force -ErrorAction SilentlyContinue)
    $sum = 0L
    foreach ($file in $files) {
        $sum += [long]$file.Length
    }
    return [pscustomobject]@{ Files = $files.Count; Bytes = [long]$sum }
}

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Remove-SafeChildren {
    param([Parameter(Mandatory)][string]$Root)

    $deleted = 0
    $failed = 0
    foreach ($item in Get-SafeChildren -Root $Root) {
        try {
            # 仅删除根目录内部已枚举出的直接子项，不删除白名单根目录本身。
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
            $deleted++
        }
        catch {
            $failed++
            Write-Warning "跳过正在使用或无权访问的项目：$($item.FullName)"
        }
    }
    return [pscustomobject]@{ Deleted = $deleted; Failed = $failed }
}

$isAdmin = Test-IsAdministrator
$userTemp = [Environment]::GetFolderPath('LocalApplicationData') + '\Temp'
$windowsTemp = Join-Path $env:WINDIR 'Temp'
$updateDownload = Join-Path $env:WINDIR 'SoftwareDistribution\Download'

$targets = @(
    [pscustomobject]@{ Name = '当前用户临时文件'; Path = $userTemp; NeedsAdmin = $false },
    [pscustomobject]@{ Name = 'Windows 系统临时文件'; Path = $windowsTemp; NeedsAdmin = $true },
    [pscustomobject]@{ Name = 'Windows Update 下载缓存'; Path = $updateDownload; NeedsAdmin = $true }
)

Write-Host "`nC盘清理家 安全扫描" -ForegroundColor Cyan
Write-Host '----------------------------------------'
$totalBytes = 0L
foreach ($target in $targets) {
    $summary = Get-TreeSummary -Root $target.Path
    $totalBytes += $summary.Bytes
    $access = if ($target.NeedsAdmin -and -not $isAdmin) { '（需管理员权限）' } else { '' }
    Write-Host ("{0,-26} {1,10} / {2,7} 个文件 {3}" -f $target.Name, (Format-Size $summary.Bytes), $summary.Files, $access)
    Write-Host "  $($target.Path)" -ForegroundColor DarkGray
}
Write-Host '回收站                     将清空当前用户所有驱动器的回收站'
Write-Host '----------------------------------------'
Write-Host "临时文件与更新缓存合计：$(Format-Size $totalBytes)"

Write-Host "`n安全说明：" -ForegroundColor Yellow
Write-Host '  1. 不会删除个人文档、下载、桌面、注册表、WinSxS 或更新数据库。'
Write-Host '  2. 正在使用或无权限的文件会被跳过。'
Write-Host '  3. 回收站清空后无法通过回收站恢复。'

$confirmation = Read-Host "`n确认执行请输入 CLEAN；输入其他内容将取消"
if ($confirmation -cne 'CLEAN') {
    Write-Host '操作已取消，未删除任何文件。' -ForegroundColor Green
    exit 0
}

$results = [System.Collections.Generic.List[object]]::new()

# 用户临时目录不要求管理员权限。
$result = Remove-SafeChildren -Root $userTemp
$results.Add([pscustomobject]@{ Name = '当前用户临时文件'; Deleted = $result.Deleted; Failed = $result.Failed })

if ($isAdmin) {
    $result = Remove-SafeChildren -Root $windowsTemp
    $results.Add([pscustomobject]@{ Name = 'Windows 系统临时文件'; Deleted = $result.Deleted; Failed = $result.Failed })

    # 清理更新下载缓存前，仅临时停止相关服务；最终会恢复原先处于运行状态的服务。
    $serviceNames = @('wuauserv', 'bits')
    $runningServices = @()
    try {
        foreach ($serviceName in $serviceNames) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($null -ne $service -and $service.Status -eq 'Running') {
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                $runningServices += $serviceName
            }
        }
        $result = Remove-SafeChildren -Root $updateDownload
        $results.Add([pscustomobject]@{ Name = 'Windows Update 下载缓存'; Deleted = $result.Deleted; Failed = $result.Failed })
    }
    finally {
        foreach ($serviceName in $runningServices) {
            try { Start-Service -Name $serviceName -ErrorAction Stop }
            catch { Write-Warning "服务 $serviceName 未能自动恢复，请在“服务”中检查。" }
        }
    }
}
else {
    Write-Warning '未以管理员身份运行，已跳过 Windows Temp 和 Windows Update 缓存。'
}

try {
    Clear-RecycleBin -Force -ErrorAction Stop
    $results.Add([pscustomobject]@{ Name = '回收站'; Deleted = 1; Failed = 0 })
}
catch {
    Write-Warning "回收站清理失败或已经为空：$($_.Exception.Message)"
    $results.Add([pscustomobject]@{ Name = '回收站'; Deleted = 0; Failed = 1 })
}

Write-Host "`n清理完成：" -ForegroundColor Green
$results | Format-Table -AutoSize
Write-Host '建议重启电脑，以便系统释放仍被进程占用的临时文件。'
