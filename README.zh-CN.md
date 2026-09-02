# ADB Wi-Fi Connect Helper

[English](README.md)

一个 macOS 小工具，用来修复 Android Studio 无线调试里很常见的卡住场景：

- 手机扫码后一直显示“正在配对”
- Android Studio 的 `Pair devices using Wi-Fi` 没反应
- `adb pair` 已经成功，但 Android Studio 还是不显示手机
- 明明在同一个 Wi-Fi，APK 还是安装不到真机上

这个工具会自动扫描 Android 设备广播出来的真正无线调试连接端口，然后执行 `adb connect`。

## 为什么需要它

Android 无线调试其实分两步：

```text
adb pair    只负责授权这台电脑
adb connect 才是真正连接手机、让 Android Studio 可以安装 APK
```

很多人卡住，是因为把“配对端口”当成了“连接端口”。

```bash
adb pair 192.168.1.20:36451
```

上面的 `36451` 通常只是配对端口，用完就关。真正安装应用需要另一个端口：

```bash
adb connect 192.168.1.20:45109
```

这个工具就是帮你自动找到后面这个端口。

## 系统要求

- macOS
- Android Studio 或 Android SDK Platform-Tools
- 手机 Android 11+
- 手机和电脑在同一个局域网
- 手机已开启：开发者选项 > 无线调试

## 使用方法

下载脚本后赋予执行权限：

```bash
chmod +x adb-wifi-connect.command
```

然后双击 `adb-wifi-connect.command`，或者在终端运行：

```bash
./adb-wifi-connect.command
```

脚本会自动：

1. 找到本机 `adb`
2. 扫描 `_adb-tls-connect._tcp`
3. 解析手机当前连接端口
4. 执行 `adb connect`
5. 显示 `adb devices -l`

看到类似下面这样就成功了：

```text
192.168.1.20:45109 device product:PHY110 model:PHY110
```

## 第一次配对

如果这台电脑还没和手机配对：

1. 手机打开：开发者选项 > 无线调试 > 使用配对码配对设备
2. 运行：

```bash
./adb-wifi-connect.command --pair 192.168.1.20:36451 868723
```

配对成功后，把手机退回“无线调试”主页面，脚本会继续自动连接真正端口。

## 已知连接端口

如果你已经知道无线调试主页面上的 `IP 地址和端口`：

```bash
./adb-wifi-connect.command --connect 192.168.1.20:45109
```

## 常用选项

```bash
./adb-wifi-connect.command --skip-pair
./adb-wifi-connect.command --restart-adb
./adb-wifi-connect.command --seconds 8
```

- `--skip-pair`：跳过配对提示，只自动扫描连接端口
- `--restart-adb`：先重启 adb server
- `--seconds N`：增加扫描时间，网络慢时有用

## Android Studio 仍不显示怎么办

只要 `adb devices -l` 里已经有：

```text
192.168.x.x:xxxxx device
```

说明手机已经连接成功。此时：

1. 关闭 Android Studio 的无线配对弹窗
2. 刷新设备下拉框
3. 还不显示就重启 Android Studio
4. 重新运行本工具

## 原理

Android 无线调试会通过 Bonjour/mDNS 广播 `_adb-tls-connect._tcp` 服务。脚本使用 macOS 自带的 `dns-sd` 找到服务，再解析出当前端口，最后调用：

```bash
adb connect IP:PORT
```

## License

MIT
