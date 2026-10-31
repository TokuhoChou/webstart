# WebStart

面向 Codex 的 Windows 本地与局域网网站启动技能。

WebStart 帮助 Codex 为本地网站增加一个可双击使用的中文控制台，并处理局域网访问、重复启动、服务状态和安全关闭。它来自一个真实本地网站的迭代过程，重点不是“写一个启动脚本”，而是让非开发者也能可靠地开启、查看和停止自己的网站。

## 功能

- 双击一个 `.cmd` 文件打开中文控制台
- 输入 `开启`、`关闭`、`地址`、`状态` 或 `退出` 管理网站
- 自动显示本机地址和可用的局域网 IPv4 地址
- 重复点击启动时复用现有网站，不产生第二次 `EADDRINUSE`
- 通过网站自身的 localhost-only 控制接口关闭服务
- 不按端口强杀未知进程，避免误伤其他应用
- 自动检查启动结果，而不是在 Node 进程发出后立即宣称成功
- 附带基于 Node.js 的可复用 Windows 启动器模板

## 系统要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1
- Node.js 仅在使用附带的 Node 模板时需要

## 安装

将仓库直接克隆到 Codex 用户技能目录：

```powershell
git clone https://github.com/TokuhoChou/webstart.git "$env:USERPROFILE\.codex\skills\webstart"
```

安装后，在 Codex 中使用：

```text
$webstart
```

示例请求：

```text
使用 $webstart 为当前网站增加双击启动、关闭、局域网地址和状态查询功能。
```

如果已经安装过，更新时进入技能目录执行：

```powershell
git pull
```

## 控制台命令

| 命令 | 作用 |
| --- | --- |
| `开启` | 启动网站；如果网站已经在运行则打开现有页面 |
| `关闭` | 通过网站自身的控制接口停止服务 |
| `地址` | 显示本机与局域网访问地址 |
| `状态` | 检查服务是否运行并显示 PID |
| `退出` | 退出控制台，但保持网站继续运行 |

## 设计结构

```text
启动局域网网站.cmd
        |
        +-- 打开 site-console.ps1
                    |
                    +-- 中文命令与状态轮询
                    |
                    +-- localhost-only 控制接口
                                  |
                                  +-- 当前网站服务器
```

`.cmd` 只负责打开同一个控制台窗口。中文输入、流程控制、轮询和错误提示都放在 PowerShell 中，避免 Windows 批处理代码页导致中文命令截断或乱码。

## 安全边界

`GET /__control/status` 和 `POST /__control/shutdown` 只接受回环地址请求，局域网中的其他设备可以访问网站，但不能远程关闭服务。

WebStart 明确避免以下行为：

- 仅凭端口号判断并终止进程
- 在局域网开放关闭接口
- 在尚未确认网站启动成功时报告成功
- 在中文 PowerShell 5.1 脚本中使用无 BOM UTF-8 编码

如果网站的威胁模型还包括恶意本地网页，技能文档进一步说明了 Origin 校验或单次运行令牌方案。

## 技能内容

- [SKILL.md](SKILL.md)：Codex 执行安装、实现和排错时的主指令
- [references/build-process.md](references/build-process.md)：启动器从真实项目迭代到稳定方案的制作过程
- [references/verification.md](references/verification.md)：启动、重复启动、LAN 访问、权限、关闭与重启验收步骤
- [assets/windows-launcher/site-console.ps1](assets/windows-launcher/site-console.ps1)：兼容 Windows PowerShell 5.1 的控制台模板
- [assets/windows-launcher/启动局域网网站.cmd](assets/windows-launcher/启动局域网网站.cmd)：极简双击入口

## 验证

当前模板已经验证：

- Windows PowerShell 5.1 语法解析
- UTF-8 BOM 编码检查
- 首次启动与重复启动
- 本机 HTTP 200
- 局域网 HTTP 200
- 局域网控制请求返回 403
- 状态、关闭、再次启动与再次关闭

完整验证流程见 [references/verification.md](references/verification.md)。

## 许可证

本项目使用 [MIT License](LICENSE)。
