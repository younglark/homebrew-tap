# Adobe Photoshop 2026 (27.5) Cask

内部用的 `adobe-photoshop@27.5` 配方。安装包来自备份盘上的**原样提取**归档，不是 Adobe Admin Console / Creative Cloud 官方安装包，也不是可公开下载的直链。

## 这个包是什么

- 产物：`Adobe Photoshop 2026.app`（Universal：x86_64 + arm64，最低 macOS 13 Ventura）。
- 产品标识（静态读取 `Info.plist`，不是实机运行结果）：
  - `CFBundleIdentifier`：`com.adobe.Photoshop`
  - `CFBundleName`：`Photoshop 2026`
  - `CFBundleDisplayName`：`Adobe Photoshop 2026`
  - `CFBundleShortVersionString` / `CFBundleVersion`：`27.5.0`
  - `CFBundleGetInfoString`：`27.5.0 (20260323.r.13 dee573e)`
- 归档文件名：`Adobe_Photoshop_2026_27.5_app.tar.gz`
- 云盘路径（备份盘）：

```text
/Software/Photoshop/27.5/macOS-AppleSilicon/Adobe_Photoshop_2026_27.5_app.tar.gz
```

来源是第三方重混安装包中的主程序载荷。提取时**没有**修改 `.app` 内部任何文件：不修复、不打补丁、不重签名、不删除已有文件、不加入许可证。配方只有 `app` stanza，不会执行安装脚本，也不会关闭或绕过安全机制。

相邻的 Locales / Presets、`Library/Application Support` 以及安装器里的 AntiCC、hosts、证书等附加组件**没有**打进本归档。请自备 Adobe 账号或许可证。打包过程中**没有**在 Mac 上启动 Photoshop，也没有执行 `brew install`。

## 安装前准备

与仓库 README 相同：已安装并登录 `aliyunpan`、当前网盘是备份盘，且上面已有该归档。不要在配方里写 `driveId`。

## 安装

```bash
brew tap younglark/tap
brew install --cask younglark/tap/adobe-photoshop@27.5
```

若 `aliyunpan` 因 Homebrew 精简 `PATH` 找不到，可指定绝对路径：

```bash
ALIYUNPAN="$(brew --prefix)/bin/aliyunpan" brew install --cask younglark/tap/adobe-photoshop@27.5
```

## 卸载

```bash
brew uninstall --cask younglark/tap/adobe-photoshop@27.5
```

普通卸载只移除应用。本配方没有 `zap`，避免误删用户文档、预设或 Creative Cloud 数据。
