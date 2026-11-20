# IDA Professional 9.5 Cask

内部用的 `ida-pro@9.5` 配方。安装包来自备份盘上的提取归档，不是官方 InstallBuilder 安装器，也不是可公开下载的直链。

## 这个包是什么

- 产物：`IDA Professional 9.5.app`（Apple silicon / arm64，最低 macOS 12 Monterey）。
- 产品标识（静态读取 `Info.plist`，不是实机运行结果）：
  - `CFBundleIdentifier`：`com.hexrays.ida`
  - `CFBundleName`：`IDA Pro`
  - `CFBundleShortVersionString`：`9.5.261026.365f1f33`
  - `CFBundleVersion`：`261026`
- 归档文件名：`IDA_Professional_9.5_arm64_app.tar.gz`
- 云盘路径（备份盘）：

```text
/Software/IDA Pro/9.5/macOS-AppleSilicon/IDA_Professional_9.5_arm64_app.tar.gz
```

Cask 里的 URL 必须把路径空格写成 `%20`（`IDA%20Pro`）。策略会再解码后交给 `aliyunpan` CLI。不要在 `url` 字符串里写未编码的空格，`URI()` 会直接拒绝。

归档由官方 macOS 安装器载荷静态解包得到，保留产品 EULA 与第三方版权许可，**不含**用户激活许可证（例如 `ida.hexlic`）。打包时按安装器清单恢复了可执行位（如 `Contents/MacOS/ida` 为 0755）。这些检查都是静态的，打包过程中**没有**在 Mac 上启动 IDA，也没有执行 `brew install`。

## 安装前准备

与仓库 README 相同：Apple silicon、已安装并登录 `aliyunpan`、当前网盘是备份盘，且上面已有该归档。不要在配方里写 `driveId`。

## 安装

```bash
brew tap younglark/tap
brew install --cask younglark/tap/ida-pro@9.5
```

安装后需要自行放入 Hex-Rays 激活许可证（例如 `ida.hexlic`），位置以官方文档为准。本配方不会写入许可证、不会绕过签名、不会自动启动 IDA。

若 `aliyunpan` 因 Homebrew 精简 `PATH` 找不到，可指定绝对路径：

```bash
ALIYUNPAN="$(brew --prefix)/bin/aliyunpan" brew install --cask younglark/tap/ida-pro@9.5
```

## 卸载

```bash
brew uninstall --cask younglark/tap/ida-pro@9.5
```

普通卸载只移除应用。本配方没有 `zap`，避免误删 `~/.idapro` 或其中的许可证与数据库。
