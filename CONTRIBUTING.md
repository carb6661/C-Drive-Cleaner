# 贡献指南

感谢参与 C盘清理家。

1. Fork 仓库并创建功能分支。
2. 保持 Windows PowerShell 5.1 兼容。
3. 不得增加任意路径删除、静默确认绕过、凭据收集或联网遥测。
4. 新增清理目标时，必须在 Pull Request 中说明安全依据和恢复方式。
5. 提交前运行语法检查：

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    "$PWD\C盘清理家.ps1",
    [ref]$tokens,
    [ref]$errors
) | Out-Null
$errors
```

请使用清晰的提交信息，并同步更新 README 或 CHANGELOG。
