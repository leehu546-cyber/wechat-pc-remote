# 用家里电脑通过 Codex/SSH 控制公司电脑

目标：在家里的 Windows 电脑上打开 Codex，通过 **设置 > 连接 > SSH** 连接公司的电脑，然后让 Codex 在公司电脑上读写文件、运行命令、处理项目。

注意：这个方式不是远程桌面画面控制，而是 **SSH 远程命令/项目控制**。如果你想看到公司电脑桌面并用鼠标键盘操作，需要用公司允许的远程桌面工具，例如 Windows 远程桌面、ToDesk、向日葵、AnyDesk、Chrome Remote Desktop 等。

## 一、这个方案需要满足的条件

公司电脑必须：

- 开机。
- 不睡眠。
- 网络在线。
- 开启 OpenSSH Server。
- 允许家里电脑访问 SSH，通常是 `22` 端口。
- 你知道公司电脑的 Windows 用户名。
- 你有密码或 SSH 密钥。
- 如果公司电脑在内网，家里电脑必须先连公司 VPN，或者使用公司允许的内网访问工具。

不要把公司电脑的 `22` 端口直接暴露到公网，除非公司 IT 明确允许。更推荐使用公司 VPN、Tailscale、ZeroTier、WireGuard 这类安全网络方案，但公司电脑必须符合公司安全规定。

## 二、明天在公司电脑上操作

### 1. 查看公司电脑信息

在公司电脑打开 PowerShell，执行：

```powershell
hostname
whoami
ipconfig
```

记录：

- 电脑名，例如 `DESKTOP-47GBOSK`
- 用户名，例如 `公司域名\zhangsan` 或 `DESKTOP-47GBOSK\zhangsan`
- IP 地址，例如 `192.168.1.50`

如果你回家后需要通过公司 VPN 访问，记录 VPN 内能访问到的 IP 或主机名。

### 2. 安装 OpenSSH Server

Windows 设置方式：

1. 打开 **设置**。
2. 进入 **系统**。
3. 进入 **可选功能**。
4. 点击 **查看功能** 或 **添加可选功能**。
5. 搜索 `OpenSSH Server`。
6. 安装 **OpenSSH Server**。

也可以用管理员 PowerShell 执行：

```powershell
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

### 3. 启动 SSH 服务

用管理员 PowerShell 执行：

```powershell
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
Get-Service sshd
```

看到 `Running` 就说明 SSH 服务已经启动。

### 4. 打开防火墙 SSH 入口

用管理员 PowerShell 执行：

```powershell
Get-NetFirewallRule -Name *OpenSSH* | Select-Object Name, Enabled, Direction, Action
```

如果没有规则，执行：

```powershell
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

如果公司安全软件或公司策略禁止开放端口，需要找 IT。

### 5. 设置公司电脑不睡眠

1. 打开 **设置**。
2. 进入 **系统 > 电源**。
3. 把“接通电源后睡眠”设置为 **从不**。
4. 如果是笔记本，插上电源。
5. 不要合盖，除非已经设置合盖不睡眠。

如果公司策略强制睡眠，这个方案会不稳定。

### 6. 在公司电脑本地测试 SSH

在公司电脑 PowerShell 执行：

```powershell
ssh 用户名@localhost
```

例如：

```powershell
ssh zhangsan@localhost
```

如果本机 `localhost` 都连不上，先不要回家，说明 SSH 服务还没配置好。

## 三、在家里电脑上测试能不能连公司电脑

回到家后，先确认家里电脑能访问公司电脑。

如果公司电脑在公司内网，先连接公司 VPN。

然后在家里电脑 PowerShell 执行：

```powershell
ssh 用户名@公司电脑IP或主机名
```

例如：

```powershell
ssh zhangsan@192.168.1.50
```

或者：

```powershell
ssh zhangsan@DESKTOP-47GBOSK
```

第一次连接会问是否信任主机，输入：

```text
yes
```

然后输入公司电脑密码。

如果能进入远程 PowerShell，说明家里电脑已经能控制公司电脑的命令行。

如果提示超时、拒绝连接、找不到主机，说明网络、VPN、防火墙或 SSH 服务还有问题。

## 四、推荐配置 SSH 密钥

密码可以用，但更推荐 SSH 密钥。

### 1. 在家里电脑生成密钥

在家里电脑 PowerShell 执行：

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\company_pc_ed25519"
```

一路回车即可。

### 2. 把公钥复制到公司电脑

在家里电脑查看公钥：

```powershell
Get-Content "$env:USERPROFILE\.ssh\company_pc_ed25519.pub"
```

复制输出内容。

在公司电脑上，把这段内容追加到：

```text
C:\Users\公司电脑用户名\.ssh\authorized_keys
```

如果没有 `.ssh` 文件夹，就新建。

注意：`authorized_keys` 是文件，不是文件夹。

### 3. 用密钥测试

在家里电脑执行：

```powershell
ssh -i "$env:USERPROFILE\.ssh\company_pc_ed25519" 用户名@公司电脑IP或主机名
```

能登录就成功。

## 五、在家里电脑写 SSH 配置

在家里电脑打开这个文件：

```text
C:\Users\你的家里电脑用户名\.ssh\config
```

没有就新建。

加入：

```text
Host company-pc
  HostName 公司电脑IP或主机名
  User 公司电脑用户名
  IdentityFile C:\Users\你的家里电脑用户名\.ssh\company_pc_ed25519
```

如果暂时用密码登录，可以去掉 `IdentityFile` 那一行。

然后在家里电脑 PowerShell 测试：

```powershell
ssh company-pc
```

能登录才继续下一步。

## 六、在 Codex 里添加 SSH 连接

你截图里的页面就是这里：

**Codex > 设置 > 连接 > SSH**

操作：

1. 在家里电脑打开 Codex。
2. 进入 **设置**。
3. 进入 **连接**。
4. 点击 **SSH**。
5. 点击 **添加**。
6. 选择或输入刚才配置的 SSH Host，例如 `company-pc`。
7. 按提示连接。
8. 选择公司电脑上的项目目录。

Codex 添加成功后，你就可以在家里电脑上创建线程，让 Codex 在公司电脑的项目目录里运行命令、读写文件。

## 七、公司电脑上还需要 Codex 吗

SSH 方案下，Codex 会通过 SSH 在远程机器启动远程服务。公司电脑上需要能运行 `codex` 命令。

明天在公司电脑 PowerShell 执行：

```powershell
codex --version
```

如果提示找不到命令，需要在公司电脑安装 Codex，或者确认 Codex CLI 已经加入 PATH。

## 八、常见错误

### 1. `Connection timed out`

通常是：

- 家里电脑没有连公司 VPN。
- 公司电脑 IP 不对。
- 公司电脑睡眠或关机。
- 公司防火墙拦了 `22` 端口。
- 公司网络不允许从外部访问。

### 2. `Connection refused`

通常是：

- 公司电脑没启动 SSH 服务。
- `sshd` 服务没运行。
- SSH 端口不是 `22`。

### 3. `Permission denied`

通常是：

- 用户名错。
- 密码错。
- SSH 密钥没放进公司电脑的 `authorized_keys`。
- 公司电脑禁用了密码登录或密钥登录。

### 4. Codex 里添加不到主机

先确认家里电脑 PowerShell 里这个命令能成功：

```powershell
ssh company-pc
```

Codex 依赖本机 SSH 配置。如果 PowerShell 不能连，Codex 也不能连。

## 九、离开公司前一定要做的最终测试

明天下班前：

1. 公司电脑保持开机。
2. 公司电脑不睡眠。
3. SSH 服务 `sshd` 是 `Running`。
4. 公司电脑能运行 `codex --version`。
5. 用另一台设备或手机热点模拟外部网络。
6. 家里电脑或测试电脑执行：

   ```powershell
   ssh company-pc
   ```

7. 能登录后，再打开 Codex 添加 SSH。

只要 `ssh company-pc` 能成功，Codex 的 SSH 连接才有基础。

## 十、如果你要的是完整桌面控制

如果你的目标是像坐在公司电脑前一样操作桌面、软件、鼠标键盘，那么 Codex 的 SSH 页面不是最合适的入口。

完整桌面控制更适合：

- Windows 远程桌面 RDP
- ToDesk
- 向日葵
- AnyDesk
- Chrome Remote Desktop
- 公司 IT 提供的远程办公工具

这类工具同样要求公司电脑开机、不睡眠，并且公司安全策略允许远程控制。
