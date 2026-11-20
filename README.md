# homebrew-tap

内部使用的 macOS Homebrew tap。仓库可以公开，但 Cask 安装包从你自己的阿里云盘拉取，执行 `brew install` 的机器需要已安装并登录 [tickstep/aliyunpan](https://github.com/tickstep/aliyunpan)。外人即使看到配方，没有你的登录会话也下不到文件。

## 安装前准备

1. 在 Apple silicon Mac 上安装 Homebrew。
2. 安装 `aliyunpan` CLI（v0.4.0 或兼容版本）。用 Homebrew 安装时，二进制通常在 `$(brew --prefix)/bin/aliyunpan`。不要指望 `depends_on formula`：Homebrew 会先下载 Cask，再安装 formula 依赖。`brew install` 会精简 `PATH`，策略会另外查找 `HOMEBREW_PREFIX/bin` 和 `HOMEBREW_PATH`。若仍找不到，可在单次命令中指定绝对路径：`ALIYUNPAN="$(brew --prefix)/bin/aliyunpan" brew install --cask younglark/tap/mumuplayer@1.9.9.forge`。
3. 运行 `aliyunpan login` 完成授权。`brew install` 过程中不会弹出登录。
4. 确认当前网盘是**备份盘**（`aliyunpan who`）。配方不会写入 `driveId`，也不会切换你的网盘、账号或 `savedir`。
5. 确认备份盘上已有对应归档，例如：

```text
/Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz
/Software/mumuplayer/1.9.9.forge/MuMuPlayer_Pro_1.9.9.forge_app.tar.gz
/Software/IDA Pro/9.5/macOS-AppleSilicon/IDA_Professional_9.5_arm64_app.tar.gz
/Software/Photoshop/27.5/macOS-AppleSilicon/Adobe_Photoshop_2026_27.5_app.tar.gz
```

## 添加 tap 并安装

```bash
brew tap younglark/tap
brew install --cask younglark/tap/mumuplayer@1.9.9
```

Forge 版本：

```bash
brew tap younglark/tap
brew install --cask younglark/tap/mumuplayer@1.9.9.forge
```

`brew tap younglark/tap` 会克隆本仓库 `younglark/homebrew-tap`。也可以一次完成：

```bash
brew install --cask younglark/tap/mumuplayer@1.9.9
```

详细说明见 [MUMUPLAYER-SETUP.md](MUMUPLAYER-SETUP.md)、[MUMUPLAYER-FORGE-SETUP.md](MUMUPLAYER-FORGE-SETUP.md)、[IDA-PRO-9.5-SETUP.md](IDA-PRO-9.5-SETUP.md) 和 [PHOTOSHOP-27.5-SETUP.md](PHOTOSHOP-27.5-SETUP.md)。

IDA Professional 9.5（提取后的 arm64 应用包，需自备激活许可证）：

```bash
brew tap younglark/tap
brew install --cask younglark/tap/ida-pro@9.5
```

Adobe Photoshop 2026 27.5（从第三方安装包原样提取的应用，需自备 Adobe 账号或许可证；不是官方安装包，未在 Mac 上验证运行）：

```bash
brew tap younglark/tap
brew install --cask younglark/tap/adobe-photoshop@27.5
```

## 卸载

普通卸载只移除应用，不删除用户数据：

```bash
brew uninstall --cask younglark/tap/mumuplayer@1.9.9
```

只有加上 `--zap` 时，才会按配方中的 `zap trash` 列表删除相关支持文件，可能同时清掉其他 MuMu 版本共享的数据。`ida-pro@9.5` 没有 `zap`，卸载不会触碰 `~/.idapro`。`adobe-photoshop@27.5` 也没有 `zap`，卸载不会触碰用户文档或 Creative Cloud 数据。

## 维护

发布或更新归档时：

1. 把 `MuMuPlayer_Pro_<version>_app.tar.gz` 放到备份盘 `/Software/mumuplayer/<version>/`。不要把包放在网盘根目录，也不要在仓库里创建公开分享直链。
2. 计算 SHA-256（`shasum -a 256` 或 `sha256sum`），写入对应 Cask 的 `sha256`。
3. 云盘路径已经由 URL 模板 `aliyunpan:///Software/mumuplayer/#{version}/MuMuPlayer_Pro_#{version}_app.tar.gz` 生成；新版本一般只需复制 Cask、改 `version` / `sha256` / 描述。
4. 自定义下载策略在 `lib/aliyunpan_download_strategy.rb`。Cask 必须通过 `Tap.fetch("younglark/tap")` 加载它，不要改回 `require_relative`：Homebrew 会把 Cask 复制到 Caskroom 的 `.metadata`，相对路径会失效。
5. 不要在公开配方中写入 `driveId`、令牌、配置路径或个人联系方式。
6. 修改策略后运行：

```bash
ruby test/aliyunpan_download_strategy_test.rb
```

测试使用假 CLI，不访问网络，也不会改动本机 `aliyunpan` 配置。

## 测试范围

- 已在 Linux 上运行上述无网络自动化测试（成功下载、缓存、路径空格、缺少 CLI、未登录、非零退出、退出码 0 但缺文件、SHA-256 不一致、不修改账号/网盘/savedir、以及从 `.metadata` 路径加载策略）。
- `ida-pro@9.5` 的自动化测试覆盖 Cask 结构、`IDA%20Pro` 路径解码、下载后的云盘层级路径，以及示例 `.app` 归档对可执行位与符号链接的保留。不把软件二进制放进仓库。
- `adobe-photoshop@27.5` 的自动化测试覆盖 Cask 结构、策略 prelude、云盘路径与下载层级、配方不含安装/卸载脚本或 `driveId`，以及示例 `.app` 归档对可执行位与符号链接的保留。不把软件二进制放进仓库。
- 本环境没有 Homebrew，也不是 macOS，因此**未做** `brew tap` / `brew install --cask` / 实际安装或运行 MuMuPlayer / IDA / Photoshop 的实测。IDA 与 Photoshop 归档只做过静态校验（版本、架构、权限等），没有在 Mac 上启动。
