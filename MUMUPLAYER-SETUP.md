# mumuplayer@1.9.9 说明

本仓库提供 Homebrew Cask `mumuplayer@1.9.9`，对应备份盘归档 `/Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz`（仅 arm64）。安装时由本机已登录的 `aliyunpan` CLI 下载，而不是匿名 HTTP。

归档 SHA-256：`1d1a27907dbcc7270e0f925c816c291dbd3f21c0bc96aab05d1296fa93b5f440`。

源码仓库及其中草稿 Release 附件仍保持私有，不在本配方下载路径中。这是对第三方软件的再分发，使用或对外提供前请自行确认授权。

## 安装前准备

- 已安装 [tickstep/aliyunpan](https://github.com/tickstep/aliyunpan)，并且 `aliyunpan` 在 `PATH` 中。
- 已运行 `aliyunpan login`。`brew install` 不会发起交互登录。
- 当前网盘为备份盘（`aliyunpan who`）。配方不会切换网盘，也不写入 `driveId`。
- 备份盘上存在上述归档。

## 安装命令

```bash
brew tap younglark/tap
brew install --cask younglark/tap/mumuplayer@1.9.9
```

也可以直接：

```bash
brew install --cask younglark/tap/mumuplayer@1.9.9
```

上述安装命令尚未在 macOS 上执行过 `brew install` 实测。本环境是 Linux，只运行了不访问网络的假 CLI 自动化测试。

## 卸载与 zap

普通卸载（`brew uninstall --cask younglark/tap/mumuplayer@1.9.9`）只移除应用，不会清理用户数据。仅在执行 `brew uninstall --cask --zap younglark/tap/mumuplayer@1.9.9` 时，才会按配方中的 `zap trash` 列表删除相关支持文件。该列表取自官方 Cask [mumuplayer.rb](https://github.com/Homebrew/homebrew-cask/blob/9f3d40158a3eb663be851d2043a6ed87041a2aa3/Casks/m/mumuplayer.rb)，可能同时清掉其他 MuMu 版本共享的数据。本草稿未实际执行卸载或 zap。

## 版本与更新

本 Cask 固定为 1.9.9，未设置 `auto_updates`。软件自身若带更新器，其行为独立于 Homebrew，不会自动更新本配方的版本号和 sha256。

## 已做与未做的检查

- 已做：Cask 仍安装 `MuMuPlayer.app`，保留 arm64 / macOS Big Sur 约束、原 SHA-256、以及原 zap 列表；下载策略用参数数组调用 `aliyunpan download --saveto <dir> --np <path>`，并校验产物确实落到 Homebrew 缓存且扩展名为 `.tar.gz`；用假 CLI 覆盖成功、缓存、路径空格、缺少 CLI、未登录、失败、退出码 0 但缺文件、校验不一致等路径。
- 未做：未执行应用、未安装到 `/Applications`、未在 macOS 上 `brew install` / `brew tap` / `brew uninstall` / `--zap`，因此不保证 Homebrew 实际安装或卸载流程一次成功，也未清理任何用户数据。
