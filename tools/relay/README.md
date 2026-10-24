# SPCL 联机中继部署说明

SPCL 的联机功能基于 [EasyTier](https://github.com/EasyTier/EasyTier)：房主和加入者都连接同一个中继节点，由它帮助互相发现、打洞，打洞失败时转发流量。

中继节点就是一台普通公网服务器 + 一个 TCP/UDP 端口，**不需要域名、不需要备案**。

## 1. 服务器选购建议

| 项 | 建议 |
| --- | --- |
| 规格 | 1 核 1G 足够（EasyTier 是 Rust 写的，中继几乎不吃 CPU） |
| 流量 | 每位玩家约 0.1–0.3 MB/s；4 人每天玩 2 小时约每月 150–250 GB，选 500GB–1TB 流量包 |
| 地区 | 香港 / 日本 / 新加坡（延迟 30–80ms、免备案、带宽大）；国内机延迟低但带宽小、流量贵；美西不推荐 |
| 价格 | 轻量云 1核1G 30Mbps 500GB 约 ¥24–35/月；也可用 Oracle Cloud 免费 ARM 机 |
| 端口 | 放行 **TCP 11010 与 UDP 11010**（UDP 决定能否 P2P 打洞；只开 TCP 会全部退化走中继） |

## 2. 部署中继（二选一）

### 方式 A：systemd（推荐）

```bash
# 下载并解压 EasyTier
cd /tmp
wget https://ghfast.top/https://github.com/EasyTier/EasyTier/releases/download/v2.6.4/easytier-linux-x86_64-v2.6.4.zip
apt install unzip -y && unzip easytier-linux-x86_64-v2.6.4.zip
mkdir -p /opt/easytier
cp easytier-linux-x86_64/easytier-core easytier-linux-x86_64/easytier-cli /opt/easytier/
chmod +x /opt/easytier/easytier-*

# 安装服务
cp easytier-core.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now easytier-core
systemctl status easytier-core --no-pager
```

### 方式 B：Docker

```bash
docker compose up -d
docker logs -f spcl-relay
```

### 关键参数说明

| 参数 | 含义 |
| --- | --- |
| `--relay-network-whitelist S*` | 只为以 `S` 开头的网络转发（SPCL 创建的房间网络名固定以 `S` 开头），避免被陌生网络借用带宽 |
| `--machine-id` / `--hostname` | 节点固定标识与显示名 |
| `-l tcp://0.0.0.0:11010` / `-l udp://0.0.0.0:11010` | 组网/中继入口 |

**注意**：

- 中继**不要**写 `--network-name` / `--network-secret` / `-i`，也**不要**加 `--private-mode`——它是纯转发节点，不加入任何网络；访问控制交给白名单。
- 想限制被滥用时的带宽，可加 `--foreign-relay-bps-limit 5MB`（示例值，按需调整）。

## 3. 放行防火墙 / 安全组

```bash
firewall-cmd --add-port=11010/tcp --permanent
firewall-cmd --add-port=11010/udp --permanent
firewall-cmd --reload
```

云厂商控制台的**安全组**同样要放行 TCP 与 UDP 11010。

## 4. 验证中继是否工作

```bash
/opt/easytier/easytier-cli node
/opt/easytier/easytier-cli peer     # cost 列：Local / p2p / relay
/opt/easytier/easytier-cli route
ss -lntup | grep 11010
```

客人在 SPCL 里创建/加入房间后，`peer` 列表里应能看到对应节点；`cost` 显示 `p2p` 表示已直连，`relay` 表示经中继转发（两者都正常）。

## 5. 在 SPCL 里使用

1. 房主与加入者都要打开 **设置 → 联机 → 中继服务器**，填写同一个地址，例如 `tcp://你的服务器IP:11010`
2. 房主：进入 **联机 → 创建房间**，在游戏里「对局域网开放」，然后把游戏给出的端口号填进启动器
3. 把生成的邀请码发给朋友（可以带 `【】` 整段复制）
4. 加入者：**联机 → 加入房间**，粘贴邀请码；完成后把页面显示的 `localhost:端口` 填进 Minecraft 的「直接连接」

## 6. 故障排查

| 现象 | 检查 |
| --- | --- |
| 一直卡在「连接到节点」 | 地址/端口是否正确；安全组与本机防火墙是否放行 TCP+UDP；`ss -lntup \| grep 11010` 是否有监听 |
| 能连上中继但组不进房间 | 网络名是否匹配白名单 `S*`；房主与加入者填写的中继地址是否完全一致 |
| 一直是 `relay` 没有 `p2p` | UDP 11010 未放行（打洞需要 UDP）；对称 NAT 下只能走中继，属正常 |
| 中继带宽被打满 | 收窄 `--relay-network-whitelist`，或加 `--foreign-relay-bps-limit` 限速 |

## 7. 安全提醒

- 中继地址只发给朋友，**不要提交到公开仓库**（SPCL 的发布包刻意不内置中继地址）
- 房间的网络名不是密码；真正的凭据是邀请码里的随机网络密钥，中继本身不需要知道它
- 中继节点不加入任何虚拟网络，也不持有任何房间密钥，只按白名单转发