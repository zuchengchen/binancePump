# Binance PUMP 检测器 - Julia 版本

> Julia 实现的币安交易异常检测工具，功能完全对应 Python 版本

## 项目简介

这是一个用 Julia 语言重写的币安 PUMP 检测器，提供与 Python 版本完全相同的功能：

- 📊 实时监控币安交易所的所有交易对
- 🔍 自动检测价格和成交量的异常变化
- 📈 四种排行榜输出（ticks、总价格变化、相对价格变化、成交量变化）
- 📱 Telegram Bot 通知功能
- 📜 历史数据获取支持
- 🛡️ 优雅退出机制（Ctrl+C）

## 为什么选择 Julia？

- **高性能**：Julia 的编译后性能接近 C/C++
- **并发优势**：原生支持轻量级 Tasks，比 Python 的 GIL 更高效
- **类型安全**：静态类型系统，编译时错误检查
- **易读性**：语法简洁，类似 Python 和 MATLAB

## 文件结构

```
binancePump/
├── src/                          # 源代码目录
│   ├── BinancePump.jl            # 模块定义
│   ├── main.jl                   # 主程序入口
│   ├── pricechange.jl             # PriceChange 结构体
│   ├── pricegroup.jl              # PriceGroup 结构体
│   ├── binancehelper.jl           # 币安 API 辅助函数
│   ├── websocketclient.jl         # WebSocket 客户端
│   └── telegrambot.jl            # Telegram Bot 封装
├── binancePump.jl               # 入口脚本
├── Project.toml                  # Julia 项目配置
├── api_config.json               # API 密钥配置（模板）
├── telegram_config.json          # Telegram 配置（模板）
└── README.md                   # 本文件
```

## 安装依赖

### 1. 安装 Julia

下载并安装 Julia 1.6 或更高版本：[https://julialang.org/downloads/](https://julialang.org/downloads/)

### 2. 安装依赖包

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

或者手动安装：

```bash
julia
```

在 Julia REPL 中：

```julia
using Pkg
Pkg.add(["HTTP", "JSON3", "Dates", "StructTypes"])
```

## 配置

### API 配置

创建 `api_config.json` 文件（已提供模板）：

```json
{
    "api_key": "你的币安API_Key",
    "api_secret": "你的币安API_Secret"
}
```

### Telegram Bot 配置（可选）

创建 `telegram_config.json` 文件（已提供模板）：

```json
{
    "bot_token": "你的Telegram_Bot_Token",
    "chat_ids": [123456789, 987654321]
}
```

**如何获取 Telegram Bot Token？**

1. 在 Telegram 中搜索 [@BotFather](https://t.me/BotFather)
2. 发送 `/newbot` 命令
3. 按照提示创建机器人
4. 复制获得的 token

**如何获取 Chat ID？**

1. 在 Telegram 中搜索 [@userinfobot](https://t.me/userinfobot)
2. 发送任意消息
3. 获取你的 Chat ID

## 运行程序

### 方式一：直接运行入口脚本

```bash
julia binancePump.jl
```

### 方式二：在 Julia REPL 中运行

```julia
push!(LOAD_PATH, joinpath(@__DIR__, "src"))
using BinancePump
start_monitoring()
```

### 方式三：使用项目环境

```bash
julia --project=. --startup-file=no -e 'push!(LOAD_PATH, "src"); include("binancePump.jl")'
```

## 配置参数

在 `src/main.jl` 中可以修改以下参数：

```julia
const SHOW_ONLY_PAIR = "USDT"  # 只显示包含 USDT 的交易对，设为 "" 显示所有
const SHOW_LIMIT = 1             # 每个排行榜显示的数量
const MIN_PERC = 0.05           # 最小变化百分比（5%）
```

## 输出说明

程序会实时输出检测到的异常交易对：

```
Top Ticks
Symbol:BTCUSDT    Time:2026-02-01T12:30:45    Ticks:15    RPCh:3.45    TPCh:8.92    VCh:12.34    LP:43500.50    LV:1234.56

Top Total Price Change
Symbol:ETHUSDT    Time:2026-02-01T12:30:45    Ticks:8    RPCh:5.67    TPCh:15.23    VCh:20.11    LP:2340.80    LV:5678.90
```

### 字段说明

| 字段 | 含义 |
|------|------|
| Symbol | 交易对名称 |
| Time | 最后一次检测到异常的时间 |
| Ticks | 触发异常的次数 |
| RPCh | 相对价格变化百分比 |
| TPCh | 总价格变化百分比 |
| VCh | 成交量变化百分比 |
| LP | 最新价格 |
| LV | 最新成交量 |

## Telegram 通知

如果配置了 Telegram Bot，程序会在检测到异常时发送通知：

```
🔥 *Top PUMP Alert*

Symbol: `BTCUSDT`
Price: 43500.50
Ticks: 15
Price Change: 3.45%
Volume: 1234.56
```

## 停止程序

按 `Ctrl + C` 即可优雅退出程序：

```
^C
Interrupt received

Shutting down...
Clean exit complete.
```

## 与 Python 版本的对比

| 特性 | Python 版本 | Julia 版本 |
|------|-------------|------------|
| 实时 WebSocket 监控 | ✅ | ✅ |
| 价格/成交量异常检测 | ✅ | ✅ |
| 四种排行榜输出 | ✅ | ✅ |
| Telegram Bot 通知 | ✅ | ✅ |
| 历史数据获取 | ✅ | ✅ |
| 优雅退出 | ✅ | ✅ |
| 性能 | 中等 | **高** |
| 并发处理 | Threading + GIL | **Tasks + Channels** |
| 类型系统 | 动态 | **静态** |
| 启动速度 | 快 | **中等**（首次编译） |

## 故障排除

### 1. 依赖安装失败

```bash
# 更新包注册表
julia -e 'using Pkg; Pkg.update()'

# 重新安装
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### 2. WebSocket 连接失败

- 检查网络连接
- 确认币安服务正常运行
- 尝试使用 VPN

### 3. Telegram 通知不工作

- 确认 bot_token 正确
- 确认 chat_ids 正确
- 检查 Telegram Bot 是否被 BotFather 启用

### 4. 编译时间过长

首次运行 Julia 程序时会有编译延迟，这是正常的。后续运行会快很多。

## 性能优化建议

1. **预编译包**：运行一次程序，Julia 会自动预编译
2. **减少监控交易对**：设置 `SHOW_ONLY_PAIR` 来过滤交易对
3. **调整阈值**：适当提高 `MIN_PERC` 减少计算量

## 开发和贡献

欢迎提交 Issue 和 Pull Request！

### 测试

```bash
# 运行所有测试
julia --project=. src/main.jl

# 测试特定功能
julia --project=. -e 'using BinancePump; println("PriceChange type: ", PriceChange)'
```

## 许可证

与原 Python 版本保持一致

## 致谢

- 原项目：[ogu83/binancePump](https://github.com/ogu83/binancePump)
- [HTTP.jl](https://github.com/JuliaWeb/HTTP.jl) - HTTP 和 WebSocket 客户端
- [JSON3.jl](https://github.com/quinnj/JSON3.jl) - JSON 处理
- [Dates](https://docs.julialang.org/en/v1/stdlib/Dates/) - Julia 标准库

## 联系方式

- 原项目：[GitHub](https://github.com/ogu83/binancePump)
- Julia 版本：[GitHub](https://github.com/yourusername/binancePump-julia)

---

**注意**：本项目仅用于教育和研究目的。使用时请遵守币安 API 使用条款。
