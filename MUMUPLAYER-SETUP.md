# mumuplayer@1.9.9 草稿说明

本仓库提供 Homebrew Cask `mumuplayer@1.9.9`，对应公开 Generic 包 `root/mumuplayer` 版本 1.9.9 中的应用归档 `MuMuPlayer_Pro_1.9.9_app.tar.gz`（仅 arm64）。安装包可匿名直接下载，无需令牌。

公开下载：

```text
https://younglark.synology.me:1443/api/packages/root/generic/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz
```

包页面：

```text
https://younglark.synology.me:1443/root/-/packages/generic/mumuplayer/1.9.9
```

源码仓库 `root/MuMuPlayer` 及其中草稿 Release 附件仍保持私有，不在本配方下载路径中。这是对第三方软件的再分发，使用或对外提供前请自行确认授权。

## 安装命令

公开 tap 仓库是 `https://younglark.synology.me:1443/root/homebrew-tap`。添加 tap 并安装（名称按 `root/tap/mumuplayer@1.9.9`）：

```bash
brew tap root/tap https://younglark.synology.me:1443/root/homebrew-tap.git
brew install --cask root/tap/mumuplayer@1.9.9
```

上述安装命令尚未执行过 `brew install` 实测。配方不再读取 `GITEA_READ_TOKEN`，也不发送 Authorization 头。

## 卸载与 zap

普通卸载（`brew uninstall --cask root/tap/mumuplayer@1.9.9`）只移除应用，不会清理用户数据。仅在执行 `brew uninstall --cask --zap root/tap/mumuplayer@1.9.9` 时，才会按配方中的 `zap trash` 列表删除相关支持文件。该列表取自官方 Cask [mumuplayer.rb](https://github.com/Homebrew/homebrew-cask/blob/9f3d40158a3eb663be851d2043a6ed87041a2aa3/Casks/m/mumuplayer.rb)，可能同时清掉其他 MuMu 版本共享的数据。本草稿未实际执行卸载或 zap。

## 版本与更新

本 Cask 固定为 1.9.9，未设置 `auto_updates`。软件自身若带更新器，其行为独立于 Homebrew，不会自动更新本配方的版本号和 sha256。

## 已做与未做的检查

- 已做：归档仅含根目录 `MuMuPlayer.app`；解包后内容/权限与源一致；`codesign --verify --deep --strict` 通过；版本 1.9.9、arm64、最低系统 11.0；已匿名完整下载公开 Generic 包并校验大小与 sha256；已在 Mac 非仓库临时目录对草稿执行 `ruby -c`，结果 Syntax OK。这只是 Ruby 语法检查，不是 Homebrew 对 Cask DSL 的完整审核。
- 未做：未执行应用、未安装到 `/Applications`、未 `brew install` / `brew tap`、未 `brew uninstall` / `--zap`，因此不保证 Homebrew 实际安装或卸载流程一次成功，也未清理任何用户数据。
