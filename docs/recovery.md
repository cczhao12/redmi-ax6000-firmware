# 救砖 / 恢复

> AX6000 的 MTK U-Boot 版本不少，按键、IP、TFTP 文件名可能不同。  
> 下面给的是通用流程；**以你机器实际 U-Boot 的提示为准**。不要拿 stock bootloader 的恢复包互刷。

## 先判断状态

- **能进 LuCI/SSH**：不用救砖，直接刷回上一个 `*sysupgrade.bin`。
- **能进 U-Boot 恢复页/TFTP**：用 U-Boot 恢复。
- **完全没反应**：需要 USB-TTL 串口或编程器。

## 方法 A：U-Boot 恢复页（如果你的 U-Boot 有）

1. 断电。
2. 按住复位键（或 U-Boot 要求的按键）再上电，保持几秒。
3. 电脑网卡设静态：
   - IP `192.168.1.2`
   - 掩码 `255.255.255.0`
   - 网关 `192.168.1.1`
4. 浏览器访问 `http://192.168.1.1`，找“固件更新/恢复”页。
5. 选 **MTK U-Boot 布局**的恢复镜像（不是 sysupgrade 也可以，按 U-Boot 要求）。
6. 刷完不要立刻断电，等 U-Boot 提示完成。

> 有些 U-Boot 只开 TFTP、不开 Web；有些地址是 `192.168.6.1` 或 `192.168.0.1`。以串口/说明书提示为准。

## 方法 B：U-Boot TFTP

1. 电脑设静态 IP `192.168.1.2/24`。
2. 电脑开 TFTP 服务，目录放恢复镜像。
3. 断电，按 U-Boot 要求按住复位键上电。
4. U-Boot 会从 `192.168.1.1` 或你电脑 IP 拉取固定文件名；串口会打印它要的文件名。
5. 按串口提示的文件名改名，重试。

> 不要猜文件名；U-Boot 串口日志会写 “Loading ... from ...”。

## 方法 C：USB-TTL 串口

- 3.3V TTL，115200 8N1；**只接 GND/TX/RX，不要接 VCC**。
- 上电看 U-Boot 日志，按提示进命令行/TFTP。
- 没有串口经验的话，找有 AX6000 救砖经验的人远程协助，别带电乱接。

## 方法 D：编程器

- 拆机，读 SPI NAND/NOR，写 U-Boot + 固件。
- 需要备份原片；操作不可逆，风险最高。

## 常见坑

- **刷错布局**：stock bootloader 和 MTK U-Boot 镜像互刷，可能直接变砖。
- **TFTP 防火墙**：Windows 防火墙会挡 TFTP；临时关掉或放行。
- **网线口**：U-Boot 恢复通常只认靠近 WAN 的 LAN 口或指定口；逐个试。
- **文件名**：U-Boot 要的文件名通常不是 release 里的长文件名；按串口日志改。
- **断电**：U-Boot 写入过程中断电可能彻底变砖。

## 恢复后

1. 先刷回可用的 `*ax6000-mtkuboot*sysupgrade.bin`。
2. 进 LuCI 设 root 密码。
3. 恢复 `/etc/config` 备份（`sysupgrade -r` 或手动）。
4. 再检查 HNAT/fullcone/TCP CC。
