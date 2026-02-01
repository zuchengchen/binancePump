#!/usr/bin/env julia

using HTTP
using HTTP.WebSockets
using JSON3
using Dates

const SHOW_ONLY_PAIR = "USDT"
const SHOW_LIMIT = 1
const MIN_PERC = 0.05
const BINANCE_WS_URL = "wss://stream.binance.com:9443/ws/!ticker@arr"

struct PriceChange
    symbol::String
    prev_price::Float64
    price::Float64
    total_trades::Int
    open_price::Float64
    volume::Float64
    is_printed::Bool
    event_time::DateTime
    prev_volume::Float64
end

mutable struct PriceGroup
    symbol::String
    tick_count::Int
    total_price_change::Float64
    relative_price_change::Float64
    total_volume_change::Float64
    last_price::Float64
    last_event_time::DateTime
    open_price::Float64
    volume::Float64
    is_printed::Bool
end

function volume_change(pc::PriceChange)::Float64
    return pc.volume - pc.prev_volume
end

function volume_change_perc(pc::PriceChange)::Float64
    if pc.prev_volume == 0
        return 0.0
    end
    return (volume_change(pc) / pc.prev_volume) * 100
end

function price_change(pc::PriceChange)::Float64
    return pc.price - pc.prev_price
end

function price_change_perc(pc::PriceChange)::Float64
    if pc.prev_price == 0
        return 0.0
    end
    return (price_change(pc) / pc.prev_price) * 100
end

function console_color(pg::PriceGroup)::String
    return pg.relative_price_change < 0 ? "red" : "green"
end

function to_string(pg::PriceGroup, is_colored::Bool)::String
    pg.is_printed = true
    
    base = "Symbol:$(pg.symbol)\tTime:$(pg.last_event_time)\t" *
           "Ticks:$(pg.tick_count)\tRPCh:$(round(pg.relative_price_change, digits=2))\t" *
           "TPCh:$(round(pg.total_price_change, digits=2))\t" *
           "VCh:$(round(pg.total_volume_change, digits=2))\t" *
           "LP:$(pg.last_price)\tLV:$(pg.volume)\t"
    
    if !is_colored
        return base
    end
    
    color_code = pg.relative_price_change < 0 ? 31 : 32
    return "\e[$(color_code)m$base\e[0m"
end

price_changes = PriceChange[]
price_groups = Dict{String, PriceGroup}()
telegram_bot_token = ""
telegram_chat_ids = Int[]

function load_config(filename::String)::Dict{String, Any}
    try
        config_str = read(filename, String)
        return JSON3.read(config_str, Dict{String, Any})
    catch e
        @error "Failed to load config from $filename: $e"
        return Dict{String, Any}()
    end
end

function send_telegram_message(text::String)
    global telegram_bot_token, telegram_chat_ids
    
    if isempty(telegram_bot_token) || isempty(telegram_chat_ids)
        return
    end
    
    for chat_id in telegram_chat_ids
        try
            url = "https://api.telegram.org/bot$(telegram_bot_token)/sendMessage"
            params = Dict(
                "chat_id" => chat_id,
                "text" => text,
                "parse_mode" => "Markdown"
            )
            
            response = HTTP.post(url, 
                               ["Content-Type" => "application/json"], 
                               body=JSON3.write(params))
            
            result = JSON3.read(String(response.body))
            if !get(result, "ok", false)
                @warn "Telegram API error: $(get(result, "description", "Unknown error"))"
            end
        catch e
            @warn "Failed to send Telegram message" exception=(e, catch_backtrace())
        end
    end
end

function process_message(tickers::Vector{Dict{String, Any}})
    global price_changes, price_groups
    
    for ticker in tickers
        symbol = get(ticker, "s", "")
        
        if !isempty(SHOW_ONLY_PAIR) && !contains(symbol, SHOW_ONLY_PAIR)
            continue
        end
        
        price = parse(Float64, get(ticker, "c", "0.0"))
        total_trades = parse(Int, get(ticker, "n", "0"))
        open_price = parse(Float64, get(ticker, "o", "0.0"))
        volume = parse(Float64, get(ticker, "v", "0.0"))
        event_time_unix = parse(Int, get(ticker, "E", "0"))
        event_time = Dates.unix2datetime(event_time_unix ÷ 1000) + Dates.Millisecond(event_time_unix % 1000)
        
        price_change_idx = findfirst(pc -> pc.symbol == symbol, price_changes)
        
        if price_change_idx !== nothing
            pc = price_changes[price_change_idx]
            pc = PriceChange(
                pc.symbol,
                pc.price,
                price,
                total_trades,
                pc.open_price,
                volume,
                false,
                event_time,
                pc.volume
            )
            price_changes[price_change_idx] = pc
        else
            pc = PriceChange(
                symbol,
                price,
                price,
                total_trades,
                open_price,
                volume,
                false,
                event_time,
                volume
            )
            push!(price_changes, pc)
        end
    end
    
    sort!(price_changes, by=pc -> price_change_perc(pc), rev=true)
    
    for pc in price_changes
        if !pc.is_printed && abs(price_change_perc(pc)) > MIN_PERC && volume_change_perc(pc) > MIN_PERC
            pc = PriceChange(
                pc.symbol,
                pc.prev_price,
                pc.price,
                pc.total_trades,
                pc.open_price,
                pc.volume,
                true,
                pc.event_time,
                pc.prev_volume
            )
            
            if !haskey(price_groups, pc.symbol)
                price_groups[pc.symbol] = PriceGroup(
                    pc.symbol,
                    1,
                    abs(price_change_perc(pc)),
                    price_change_perc(pc),
                    volume_change_perc(pc),
                    pc.price,
                    pc.event_time,
                    pc.open_price,
                    pc.volume,
                    false
                )
            else
                pg = price_groups[pc.symbol]
                pg.tick_count += 1
                pg.last_event_time = pc.event_time
                pg.volume = pc.volume
                pg.last_price = pc.price
                pg.is_printed = false
                pg.total_price_change += abs(price_change_perc(pc))
                pg.relative_price_change += price_change_perc(pc)
                pg.total_volume_change += volume_change_perc(pc)
            end
        end
    end
    
    if !isempty(price_groups)
        print_rankings()
    end
end

function print_rankings()
    global price_groups, SHOW_LIMIT
    
    sorted_symbols = collect(keys(price_groups))
    
    println("\nTop Ticks")
    sort!(sorted_symbols, by=s -> price_groups[s].tick_count, rev=true)
    for (i, s) in enumerate(sorted_symbols)
        if i >= SHOW_LIMIT
            break
        end
        pg = price_groups[s]
        if !pg.is_printed
            println(to_string(pg, true))
        end
    end
    
    println("\nTop Total Price Change")
    sort!(sorted_symbols, by=s -> price_groups[s].total_price_change, rev=true)
    for (i, s) in enumerate(sorted_symbols)
        if i >= SHOW_LIMIT
            break
        end
        pg = price_groups[s]
        if !pg.is_printed
            println(to_string(pg, true))
        end
    end
    
    println("\nTop Relative Price Change")
    sort!(sorted_symbols, by=s -> abs(price_groups[s].relative_price_change), rev=true)
    for (i, s) in enumerate(sorted_symbols)
        if i >= SHOW_LIMIT
            break
        end
        pg = price_groups[s]
        if !pg.is_printed
            println(to_string(pg, true))
        end
    end
    
    println("\nTop Total Volume Change")
    sort!(sorted_symbols, by=s -> price_groups[s].total_volume_change, rev=true)
    for (i, s) in enumerate(sorted_symbols)
        if i >= SHOW_LIMIT
            break
        end
        pg = price_groups[s]
        if !pg.is_printed
            println(to_string(pg, true))
        end
    end
    
    println()
end

function main()
    global telegram_bot_token, telegram_chat_ids
    
    println("Loading configuration...")
    
    api_config = load_config("api_config.json")
    telegram_config_dict = load_config("telegram_config.json")
    telegram_bot_token = get(telegram_config_dict, "bot_token", "")
    
    chat_ids_data = get(telegram_config_dict, "chat_ids", Any[])
    if isa(chat_ids_data, Vector)
        telegram_chat_ids = Int[chat_id for chat_id in chat_ids_data]
    end
    
    if !isempty(telegram_bot_token) && !isempty(telegram_chat_ids)
        println("Telegram notifications enabled with $(length(telegram_chat_ids)) chat ID(s)")
    else
        println("Telegram notifications disabled")
    end
    
    println("Connecting to Binance WebSocket...")
    
    running = true
    
    task = @async begin
        try
            WebSockets.open(BINANCE_WS_URL) do ws
                @info "WebSocket connected to $(BINANCE_WS_URL)"
                
                while running && isopen(ws)
                    try
                        msg = receive(ws)
                        data = JSON3.read(String(msg), Vector{Dict{String, Any}})
                        process_message(data)
                    catch e
                        if e isa WebSockets.WebSocketClosedError
                            @info "WebSocket closed normally"
                            break
                        else
                            @warn "WebSocket receive error" exception=(e, catch_backtrace())
                            break
                        end
                    end
                end
                
                @info "WebSocket disconnected"
            end
        catch e
            @warn "WebSocket connection error" exception=(e, catch_backtrace())
        end
    end
    
    atexit() do
        global running = false
        println("\nShutting down...")
    end
    
    println("Websocket running. Press Ctrl+C to exit.")
    
    try
        while true
            sleep(1)
        end
    catch e
        if e isa InterruptException
            println("\nInterrupt received")
        end
    end
    
    println("Clean exit complete.")
end

main()
