# mumuplayer@1.9.9.forge 说明

本仓库提供 Homebrew Cask `mumuplayer@1.9.9.forge`，对应公开 Generic 包 `root/mumuplayer` 版本 `1.9.9.forge` 中的应用归档 `MuMuPlayer_Pro_1.9.9.forge_app.tar.gz`（仅 arm64）。

公开下载：

```text
https://younglark.synology.me:1443/api/packages/root/generic/mumuplayer/1.9.9.forge/MuMuPlayer_Pro_1.9.9.forge_app.tar.gz
```

包页面：

```text
https://younglark.synology.me:1443/root/-/packages/generic/mumuplayer/1.9.9.forge
```

归档 SHA-256：`d8dc31ac08f69f459f651a032dcc24fc92407071dc7aa259ed5c35a254c4e21d`，大小 827,468,634 字节。

## 与 mumuplayer@1.9.9 的区别

- 注入的 `libmumu.dylib` 改为仓库 `root/MuMuPlayer` 中 `libmumu-reconstructed` 的 arm64 构建，并同时放入外层应用和内层 `MuMuEmulator.app`。
- 按 `FRIDA_IMAGE_PATCH.md` 修改 `system.qcow2`：写入 `/system/xbin/frida-server`（17.16.4），在 Android `early-init` 设置 SELinux permissive，并在 Root Access 开启且 `sys.boot_completed=1` 后监听来宾 `127.0.0.1:27042`。
- 应用使用 ad-hoc 重签，保留 `com.apple.security.hypervisor` 等 entitlements，未启用 hardened runtime，便于 Frida/LLDB attach 宿主进程。

应用自身的 `CFBundleShortVersionString` 仍为 `1.9.9`；`1.9.9.forge` 是本次发布标签。

现有 MuMu 实例直接使用应用包内的 `system.qcow2`，安装本版本后会随应用一起切换到打过 Frida 补丁的镜像。Frida 只在实例的 Root Access 开启时启动；关闭 Root Access 会停止 Frida，但 SELinux 保持 permissive 直到 Android 下次重启。

## 安装与卸载

```bash
brew tap root/tap https://younglark.synology.me:1443/root/homebrew-tap.git
brew install --cask root/tap/mumuplayer@1.9.9.forge
```

普通卸载只移除应用，不清理实例数据。`--zap` 会按配方中的 `zap trash` 列表删除相关支持文件，可能同时清掉其他 MuMu 版本共享的数据。

## 验证范围

- 归档解包后的 `codesign --verify --deep --strict` 通过，arm64，最低系统 11.0。
- 外层 `MuMuPlayer` 和内层 `MuMuEmulator` 均保留 `com.apple.security.hypervisor`。
- `libmumu-reconstructed` 的 115 项路由检查全部通过（`libmumu-reconstructed/tests/run_tests.sh`）。
- `system.qcow2` 的 `qemu-img check` 通过；从 ext4 中回读的 `frida-server` 与下载文件 SHA-256 一致，init 补丁内容一致。
- 未执行 `brew install`；未启动应用进行完整的 VM 启动和 Frida 连接测试。

这是对第三方软件的再分发和修改，官方签名已失效，`spctl` 会拒绝。仅供个人技术研究，使用前请自行确认授权。
