# SafeTempCleaner

一个面向 Windows 10/11 的开源 PowerShell 安全清理脚本。它专注于清理可重新生成的系统垃圾，同时通过固定白名单、执行前预览和强制人工确认降低误删风险。

## 功能

- 清理当前用户临时目录：`%USERPROFILE%\AppData\Local\Temp`
- 清理系统临时目录：`C:\Windows\Temp`
- 清理 Windows Update 下载缓存：`C:\Windows\SoftwareDistribution\Download`
- 清空当前用户回收站
- 删除前统计文件数量与空间占用
- 只有准确输入 `CLEAN` 才开始执行
- 自动跳过正在使用或无权限访问的文件
- 清理更新缓存时恢复原先正在运行的 Windows Update/BITS 服务

> [!IMPORTANT]
> 脚本不会清理 `SoftwareDistribution\DataStore`、`WinSxS`、注册表、下载目录、桌面或个人文档。Windows Update 下载缓存被清理后，系统可能在下次检查更新时重新下载需要的文件。

## 系统要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1 或 PowerShell 7+
- 建议以管理员身份运行；非管理员模式只清理用户临时目录和回收站

## 使用方法

1. 下载或克隆本仓库。
2. 右键开始菜单，选择“Windows PowerShell（管理员）”或“终端（管理员）”。
3. 进入脚本所在目录并执行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\SafeTempCleaner.ps1
```

`Set-ExecutionPolicy -Scope Process` 只影响当前 PowerShell 窗口，关闭窗口后自动失效，不会永久修改系统策略。

脚本会先展示预计清理的路径、文件数和容量。检查无误后输入大写 `CLEAN`；输入其他任何内容都会安全取消。

## 安全设计

- 目标路径在代码中固定，不接受用户传入的任意路径。
- 所有删除操作使用 `-LiteralPath`，防止通配符扩展。
- 只删除白名单根目录的子项，不删除根目录本身。
- 不使用磁盘清零、注册表修改、系统组件删除或权限接管。
- 回收站内容无法在清空后恢复，因此始终纳入确认提示。
- 不上传文件、收集遥测、请求网络或保存账号凭据。

建议首次使用前阅读 [安全策略](SECURITY.md) 和脚本源码。重要数据应始终保留独立备份。

## 项目结构

```text
SafeTempCleaner/
├── SafeTempCleaner.ps1       # 主脚本
├── README.md                 # 中文说明
├── SECURITY.md               # 安全策略与风险说明
├── CONTRIBUTING.md           # 贡献指南
├── CHANGELOG.md              # 版本记录
├── LICENSE                   # MIT 许可证
└── .github/workflows/ci.yml  # PowerShell 语法和安全边界检查
```

## 参与贡献

欢迎提交 Issue 和 Pull Request。涉及新增清理路径的改动必须说明：路径来源、为何可安全重建、最坏影响和恢复方式。

## 许可证

[MIT License](LICENSE)

