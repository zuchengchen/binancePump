# Binance PUMP 检测器（Julia 版本）- 详细使用指南

> 本指南面向初学者，手把手教你如何使用 Julia 版本的币安交易监控工具

## 目录

- [什么是这个项目？](#什么是这个项目)
- [为什么选择 Julia？](#为什么选择-julia)
- [开始前需要准备什么](#开始前需要准备什么)
- [安装步骤](#安装步骤)
- [配置 Binance API](#配置-binance-api)
- [配置 Telegram Bot（可选）](#配置-telegram-bot可选）
- [运行程序](#运行程序)
- [理解输出内容](#理解输出内容)
- [常见问题](#常见问题)
- [性能优化](#性能优化)

---

## 什么是这个项目？

这是一个 **币安（Binance）交易监控工具的 Julia 实现**，专门用来检测加密货币市场中的异常交易活动。

简单来说，它会：
1. 连接到币安的实时交易数据流
2. 收集各种交易对（比如 BTC/USDT）的价格、成交量等信息
3. 分析这些数据，找出异常的价格或成交量变化
4. 把这些"异常"展示给你看

**与 Python 版本的关系**：
- ✅ 功能完全相同
- ✅ 输出格式一致
- ✅ 配置方式类似
- 🚀 性能更高（Julia 编译后接近 C/C++）
- 🔒 类型安全（编译时错误检查）

## 为什么选择 Julia？

Julia 是一门新兴的高性能编程语言，特别适合数值计算和数据处理：

| 特性 | Julia | Python |
|------|--------|--------|
| **执行速度** | 快（编译后） | 中等（解释） |
| **类型系统** | 静态类型 | 动态类型 |
| **并发模型** | Tasks（轻量级） | Threading + GIL |
| **学习曲线** | 简单（类似 Python） | 简单 |
| **适用场景** | 高性能计算 | 快速开发 |

---

## 开始前需要准备什么

### 1. 一台电脑
- Windows、macOS 或 Linux 都可以
- 需要能连接互联网

### 2. Julia 环境
本项目需要 **Julia 1.6 或更高版本**

**如何检查是否已安装 Julia？**

打开命令行（终端）：
- Windows: 按 `Win + R`，输入 `cmd`，回车
- macOS: 按 `Cmd + Space`，输入 `terminal`，回车
- Linux: 按 `Ctrl + Alt + T`

输入以下命令：
```bash
julia --version
```

如果看到类似 `julia version 1.9.x` 的输出，说明已经安装了 ✅

如果没有安装，请访问 [julialang.org](https://julialang.org/downloads/) 下载安装

### 3. 币安账户
你需要一个币安账户来获取 API 密钥
- 注册地址：[binance.com](https://www.binance.com)
- 不需要资金，只需要注册账号即可

---

## 安装步骤

### 第一步：下载项目

你可以通过两种方式获取项目代码：

**方式一：使用 Git（推荐）**

打开命令行，进入你想保存项目的目录，然后执行：
```bash
git clone https://github.com/ogu83/binancePump.git
cd binancePump
```

**方式二：手动下载**

1. 访问项目页面：https://github.com/ogu83/binancePump
2. 点击绿色的 "Code" 按钮
3. 选择 "Download ZIP"
4. 下载后解压到任意目录
5. 打开解压后的文件夹

### 第二步：安装 Julia 依赖

在项目目录中，打开命令行，执行：

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

**这条命令会做什么？**

- `--project=.` 指定使用当前目录的 `Project.toml`
- `-e` 执行 Julia 代码
- `Pkg.instantiate()` 自动安装所有依赖包

**依赖包说明**：
- **HTTP.jl**：HTTP 请求和 WebSocket 客户端
- **JSON3.jl**：高性能 JSON 解析和序列化
- **StructTypes**：结构体 JSON 序列化支持
- **Dates**：日期和时间处理（标准库）

**如果安装失败，可以手动安装：**

```bash
julia
```

在 Julia REPL 中：

```julia
using Pkg
Pkg.add(["HTTP", "JSON3", "StructTypes"])
```

### 第三步：验证安装

```bash
julia --project=. -e 'using HTTP, JSON3, Dates, StructTypes; println("All packages installed successfully!")'
```

如果看到 "All packages installed successfully!"，说明安装成功 ✅

---

## 配置 Binance API

### 什么是 API 密钥？

API 密钥就像一把"钥匙"，让你的程序可以访问币安的数据。

### 如何获取 API 密钥？

1. **登录币安账户**
   - 访问 [binance.com](https://www.binance.com)
   - 使用你的账号密码登录

2. **进入 API 管理**
   - 点击右上角的头像图标
   - 选择 "API Management"（API 管理）

3. **创建新的 API 密钥**
   - 点击 "Create API"（创建 API）
   - 给你的 API 起个名字（比如 "PumpDetectorJulia"）
   - 可能需要输入二次验证码

4. **复制密钥**
   - 你会看到两个字符串：
     - **API Key**（公钥）
     - **Secret Key**（私钥，只显示一次！**一定要复制保存**）
   
   ⚠️ **重要提醒**：
   - Secret Key 只显示一次，**请立即复制并保存好**
   - 不要分享给你的任何人
   - 建议记录在安全的地方

5. **设置权限（可选但推荐）**
   - 为了安全，只勾选 "Enable Reading"（启用读取权限）
   - 不要勾选 "Enable Withdrawals"（启用提现权限）

### 配置项目

打开项目目录中的 `api_config.json` 文件，你会看到：

```json
{ 
    "api_key": "",
    "api_secret": ""
}
```

将你的密钥填入（注意保持引号）：

```json
{ 
    "api_key": "你的API_Key_在这里",
    "api_secret": "你的Secret_Key_在这里"
}
```

保存文件。

**小贴士**：
- 注意不要删除引号 `""`
- 确保在两个密钥之间有逗号 `,`
- 最后一行的大括号 `}` 后面不要加逗号

---

## 配置 Telegram Bot（可选）

### 什么是 Telegram Bot 通知？

配置 Telegram Bot 后，程序会在检测到市场异常时自动发送消息到你的 Telegram，无需一直盯着屏幕。

### 获取 Telegram Bot Token

1. **在 Telegram 中搜索 BotFather**
   - 搜索 [@BotFather](https://t.me/BotFather)
   - 点击 "START" 开始

2. **创建新机器人**
   - 发送 `/newbot` 命令
   - 按照提示操作：
     - 给机器人起个名字（比如 `PumpDetectorBot`）
     - 给机器人起个用户名（必须以 `bot` 结尾，比如 `MyPumpDetectorBot`）
   - 复制获得的 token（格式类似：`1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`）

### 获取你的 Chat ID

1. **在 Telegram 中搜索 userinfobot**
   - 搜索 [@userinfobot](https://t.me/userinfobot)
   - 点击 "START" 开始

2. **发送任意消息**
   - 发送 `/start` 或任意文字
   - 你会看到你的 Chat ID（类似：123456789）

### 配置 Telegram

打开项目目录中的 `telegram_config.json` 文件：

```json
{
    "bot_token": "",
    "chat_ids": []
}
```

填入你的配置：

```json
{
    "bot_token": "你的Bot_Token_在这里",
    "chat_ids": [123456789, 987654321]
}
```

**注意**：
- `chat_ids` 是一个数组，可以添加多个 ID
- 如果不想用 Telegram 通知，可以留空

---

## 运行程序

### 启动程序

在项目目录中打开命令行，输入：

```bash
julia binancePump.jl
```

你会看到类似这样的输出：

```
Loading configuration...
Telegram notifications enabled
Connecting to Binance WebSocket...
Websocket running. Press Ctrl+C to exit.
```

这表示程序已经开始运行了 ✅

### 首次运行注意

⚠️ **重要**：第一次运行 Julia 程序时，会有较长的编译时间（可能需要 1-3 分钟）。这是正常的，Julia 会编译所有用到的函数。后续运行会快很多！

### 停止程序

按 `Ctrl + C`（同时按住 Ctrl 键和 C 键）即可停止程序

程序会显示：

```
^C
Interrupt received

Shutting down...
Clean exit complete.
```

---

## 理解输出内容

程序运行后会持续监控市场，当检测到异常时会打印信息。

### 输出格式示例

```
Top Ticks
Symbol:BTCUSDT    Time:2026-02-01T12:30:45    Ticks:15    RPCh:3.45    TPCh:8.92    VCh:12.34    LP:43500.50    LV:1234.56

Top Total Price Change
Symbol:ETHUSDT    Time:2026-02-01T12:30:45    Ticks:8    RPCh:5.67    TPCh:15.23    VCh:20.11    LP:2340.80    LV:5678.90
```

### 字段说明

| 字段 | 含义 | 说明 |
|------|------|------|
| **Symbol** | 交易对名称 | 比如 `BTCUSDT` 表示比特币/泰达币交易对 |
| **Time** | 时间戳 | 最后一次检测到异常的时间 |
| **Ticks** | 触发次数 | 该交易对达到异常阈值被检测到的次数 |
| **RPCh** | 相对价格变化 | 累计的价格变化百分比（正数=涨，负数=跌） |
| **TPCh** | 总价格变化 | 累计价格变化的绝对值总和 |
| **VCh** | 成交量变化 | 成交量变化的百分比 |
| **LP** | 最新价格 | 当前的最新价格 |
| **LV** | 最新成交量 | 当前的成交量 |

### 四种排行榜

程序会显示四种不同的排行榜：

1. **Top Ticks** - 触发次数最多的币种
2. **Top Total Price Change** - 价格变化最大的币种
3. **Top Relative Price Change** - 相对价格变化最大的币种
4. **Top Total Volume Change** - 成交量变化最大的币种

### Telegram 通知格式

如果配置了 Telegram Bot，你会收到类似这样的消息：

```
🔥 *Top PUMP Alert*

Symbol: `BTCUSDT`
Price: 43500.50
Ticks: 15
Price Change: 3.45%
Volume: 1234.56
```

---

## 配置参数

在 `src/main.jl` 文件的开头，有几个配置参数可以调整：

### 只监控特定交易对

```julia
const SHOW_ONLY_PAIR = "USDT"  # 只显示包含 USDT 的交易对
```

如果你想监控所有交易对，改为：
```julia
const SHOW_ONLY_PAIR = ""  # 空字符串表示监控所有
```

### 显示数量限制

```julia
const SHOW_LIMIT = 1  # 每个排行榜只显示前 1 个
```

如果你想看更多，可以改成 5 或 10。

### 最小变化阈值

```julia
const MIN_PERC = 0.05  # 最小变化百分比（5%）
```

只有当价格或成交量变化超过 5% 时才会被检测到。

**注意**：修改配置后需要重新运行程序才能生效。

---

## 常见问题

### Q1: 首次运行时很慢

**问题**：第一次运行时，程序启动需要很长时间

**原因**：Julia 采用 JIT（即时编译），首次运行时需要编译所有用到的函数

**解决方法**：
- 耐心等待编译完成（1-3 分钟）
- 编译完成后，后续运行会非常快
- 这是 Julia 的正常行为，不是 bug

### Q2: 依赖安装失败

**问题**：
```
Error: Package HTTP not found
```

**解决方法**：
```bash
# 更新包注册表
julia -e 'using Pkg; Pkg.update()'

# 重新安装
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Q3: 连接币安时出现错误

**问题**：提示连接失败或 API 错误

**可能原因**：
1. API 密钥配置错误
2. 网络连接问题
3. 币安服务器暂时不可用

**解决方法**：
1. 检查 `api_config.json` 中的密钥是否正确
2. 检查网络连接
3. 等待几分钟后重试

### Q4: 没有任何输出

**问题**：程序运行但没有显示任何信息

**原因**：
- 当前市场没有达到阈值的异常活动
- 配置的阈值太高

**解决方法**：
尝试降低 `MIN_PERC` 的值，比如改成 `0.01`（1%）

### Q5: Telegram 通知不工作

**问题**：配置了 Telegram 但没有收到消息

**可能原因**：
1. Bot Token 错误
2. Chat ID 错误
3. Bot 被 BotFather 禁用

**解决方法**：
1. 确认 bot_token 正确
2. 确认 chat_ids 正确
3. 尝试给 Bot 发送消息，看是否正常

### Q6: 内存占用过高

**问题**：长时间运行后，内存占用越来越高

**解决方法**：
- 重启程序
- 调高 `MIN_PERC` 阈值，减少检测频率
- 定期清理过期的数据（需要修改代码）

---

## 性能优化

### 1. 预编译

第一次运行程序后，Julia 会缓存编译结果。后续运行会快很多。

### 2. 减少监控范围

设置 `SHOW_ONLY_PAIR` 只监控特定的交易对：

```julia
const SHOW_ONLY_PAIR = "USDT"  # 只监控 USDT 交易对
```

### 3. 调整检测阈值

适当提高 `MIN_PERC` 可以减少计算量：

```julia
const MIN_PERC = 0.10  # 只检测 10% 以上的变化
```

### 4. 使用编译优化

在 `binancePump.jl` 中添加：

```julia
#!/usr/bin/env julia --optim=3
```

---

## 与 Python 版本的选择

### 何时选择 Python 版本？

- 你更熟悉 Python
- 需要快速开发和调试
- 不需要极致性能
- 已有 Python 生态系统依赖

### 何时选择 Julia 版本？

- 需要高性能
- 处理大量数据
- 关注类型安全
- 喜欢学习新技术
- 愿意接受首次编译时间

---

## 高级使用

### 交互式模式

```julia
julia --project=.
```

在 Julia REPL 中：

```julia
push!(LOAD_PATH, joinpath(@__DIR__, "src"))
using BinancePump

# 直接调用函数
start_monitoring()
```

### 获取历史数据

```julia
julia --project=. -e '
push!(LOAD_PATH, "src");
using BinancePump;
klines = get_historical_klines("BTCUSDT", "1h", "2026-01-01 00:00:00");
println("Got $(length(klines)) klines")
'
```

### 自定义处理逻辑

修改 `src/main.jl` 中的 `process_message` 函数，实现你自己的逻辑。

---

## 注意事项

### 安全提醒

⚠️ **非常重要**：
- **不要** 将 `api_config.json` 和 `telegram_config.json` 上传到公开的代码仓库
- **不要** 分享你的 API 密钥给任何人
- **定期更换** API 密钥
- **不要** 勾选 API 的提现权限

本项目已经将这些文件添加到 `.gitignore`，不会被提交到 Git。

### 使用限制

- 币安 API 有访问频率限制（rate limit），不要频繁重启程序
- 只用于个人学习和研究，不要用于商业用途

### 性能建议

- 长时间运行时注意电脑性能和内存使用
- 如果监控的交易对很多，可能需要更多的系统资源

---

## 获取帮助

如果遇到问题：

1. **查看本文档**：先在常见问题部分找找答案
2. **查看代码注释**：代码中有详细的注释说明
3. **搜索网络**：使用错误信息在搜索引擎中搜索
4. **查看 Julia 文档**：[https://docs.julialang.org/](https://docs.julialang.org/)
5. **查看币安 API 文档**：[https://binance-docs.github.io/apidocs/](https://binance-docs.github.io/apidocs/)

---

## 项目文件说明

| 文件名 | 说明 |
|--------|------|
| `binancePump.jl` | 入口脚本 |
| `src/BinancePump.jl` | 模块定义 |
| `src/main.jl` | 主程序，包含核心逻辑 |
| `src/pricechange.jl` | 价格变化数据类 |
| `src/pricegroup.jl` | 价格分组数据类 |
| `src/binancehelper.jl` | 币安 API 辅助函数 |
| `src/websocketclient.jl` | WebSocket 客户端 |
| `src/telegrambot.jl` | Telegram Bot 封装 |
| `Project.toml` | Julia 依赖配置 |
| `api_config.json` | API 密钥配置（需要自己填写） |
| `telegram_config.json` | Telegram 配置（需要自己填写） |

---

## 更新日志

- v0.1.0 (2026-02-01): 初始 Julia 版本实现

---

## 许可证

与原 Python 版本保持一致

---

**祝使用愉快！如有问题欢迎反馈 🚀**

**特别说明**：本 Julia 版本与 Python 版本功能完全一致，你可以根据自己的需求选择使用哪个版本。两个版本的配置文件格式相同，可以共用！
