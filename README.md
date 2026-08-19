# dsh-oneclick-launcher

> Windows 一键启动 DeepSeek Harness（独立窗口版）
> One-click launcher for DeepSeek Harness on Windows (standalone window, not a browser tab)

## 问题 / Problem

启动 DeepSeek Harness 需要两步操作，比较繁琐：

1. 打开 PowerShell，运行 `dsh web`（服务在终端里运行）
2. 点击桌面 Chrome PWA 快捷方式，才能打开独立的 GUI 窗口

如果直接运行 `dsh web`，它会在**浏览器标签页**中打开 GUI，而不是像桌面应用那样的**独立窗口**。

## 方案 / Solution

一个 VBS 启动脚本 + 桌面快捷方式，双击即完成全部工作：

1. 检查 `3080` 端口是否已有服务在运行
2. 没有则**后台隐藏启动** `dsh web`（设置正确的工作目录，日志可查）
3. 等待服务就绪（最长 90 秒，端口轮询）
4. 用 Chrome **PWA 独立窗口**（app 模式）打开 GUI —— 不是浏览器标签页

## 文件 / Files

| 文件 | 说明 |
|------|------|
| `DeepSeekHarnessLauncher.vbs` | 一键启动脚本（VBScript，无需安装任何依赖） |
| `install.ps1` | 安装脚本：自动探测路径、生成快捷方式（可选） |

## 安装 / Install

### 方式 A：手动（最简）

1. 把 `DeepSeekHarnessLauncher.vbs` 放到任意目录（例如 `D:\softinstall\deepseeek harnees\`）
2. 打开脚本，按你的环境修改开头几行常量：

```vbscript
Const PORT = 3080                                    ' dsh web 监听端口
Const DSH_DIR = "C:\Users\10780\AppData\Roaming\npm" ' dsh 命令所在目录（npm 全局目录）
Const NODE = "D:\softinstall\nodejs\node.exe"        ' node.exe 绝对路径
Const BIN = "C:\...\node_modules\@deepseek-ai\dsh\lib\bin.js"  ' dsh bin.js 绝对路径
Const CHROME = "C:\Program Files\Google\Chrome\Application\chrome_proxy.exe"  ' Chrome
Const APP_ID = "hgiemfgfjhalibdoboikeiepnnjapnpc"    ' DeepSeek Harness PWA 的 app-id
```

3. 右键桌面 → 新建快捷方式 → 目标填：

```
wscript.exe "D:\softinstall\deepseeek harnees\DeepSeekHarnessLauncher.vbs"
```

4. 双击快捷方式即可。

### 方式 B：自动安装脚本

```powershell
# 以管理员或普通用户运行均可（安装脚本会自动探测环境）
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

`install.ps1` 会：
- 自动探测 `node.exe`、dsh 安装目录、Chrome 路径
- 探测 DeepSeek Harness 的 PWA app-id（从 Chrome Web Applications 目录）
- 生成 `DeepSeekHarnessLauncher.vbs`（写入探测到的路径）
- 在桌面创建 `DeepSeek Harness.lnk` 快捷方式

## 工作原理 / How it works

### 为什么是独立窗口而不是标签页？

`dsh web` 启动时默认在浏览器标签页打开 GUI。要在独立窗口（类桌面应用）打开，使用 Chrome 的 **PWA app 模式**：

```
chrome_proxy.exe --profile-directory=Default --app-id=<PWA_APP_ID>
```

这个 app-id 来自你首次在 Chrome 中"安装" DeepSeek Harness PWA 时生成的注册（存储在 `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Web Applications\_crx_<app-id>\`）。

### 为什么用 VBScript？

- VBScript 可以**隐藏窗口**运行 `dsh web`（服务在后台运行，不占终端）
- 双击 `.vbs` 由 `wscript.exe` 执行，无需安装 Node/Python 等运行时
- 系统自带，零依赖

### 踩坑记录（重要！）

开发这个脚本时踩过这些坑，供参考：

1. **VBScript 不区分大小写**：变量 `isListening` 和函数 `IsListening()` 同名会编译报错 → 改名避免冲突
2. **`LOG` 是 VBScript 内置函数名**（自然对数），不能用作常量 → 改名 `LOGFILE`
3. **`shell.Exec` 管道读取可能死锁**：`netstat | findstr` 的输出用 `AtEndOfStream` 判断可能卡住 → 改为重定向到临时文件再读取
4. **`cmd /c` 嵌套引号 + 路径含空格**（如 `deepseeek harnees`）会解析失败 → 用 `shell.CurrentDirectory` 设置工作目录，避免 `cmd /c`
5. **`dsh web` 需要正确的工作目录**：直接 `node bin.js --profile web` 若工作目录不对会启动失败；手动 `cd <npm目录> && dsh web` 才能成功

## 卸载 / Uninstall

1. 删除桌面快捷方式
2. 删除 `DeepSeekHarnessLauncher.vbs`
3. 如需彻底停止后台服务：任务管理器结束 `node.exe` 进程

## 许可证 / License

MIT

## 相关链接 / Links

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) — "Everything is a Plugin"
- 官方贡献指南：不接受外部 PR，但欢迎在 GitHub Discussions 分享经验和插件
