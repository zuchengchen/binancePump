#!/usr/bin/env julia

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using HTTP
using HTTP.WebSockets
using JSON3
using Dates
using SHA

const SHOW_ONLY_PAIR = "USDT"
const SHOW_LIMIT = 1
const MIN_PERC = 0.05
const BINANCE_WS_URL = "wss://stream.binance.com:9443/ws/!ticker@arr"
const BINANCE_API_URL = "https://api.binance.com"

include("src/pricechange.jl")
include("src/pricegroup.jl")

price_changes = PriceChange[]
price_groups = Dict{String, PriceGroup}()
telegram_bot_token = ""
telegram_chat_ids = Int[]
stop_event = Channel{Bool}(1)

function unix2datetime(unix_ms::Int)::DateTime
    unix_sec = unix_ms ÷ 1000
    ms_remainder = unix_ms % 1000
    return Dates.unix2datetime(unix_sec) + Dates.Millisecond(ms_remainder)
end

function load_config(filename::String)::Dict{String, String}
    try
        config_str = read(filename, String)
        return JSON3.read(config_str, Dict{String, String})
    catch e
        @error "Failed to load config from $filename: $e"
        return Dict{String, String}()
    end
end

function send_telegram_message(text::String)
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
        event_time = unix2datetime(event_time_unix)
        
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
                    pc.volume
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
                price_groups[pc.symbol] = pg
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
        if i > SHOW_LIMIT
            break
        end
        pg = price_groups[s]
        println(to_string(pg, true))
    end
    
    println("\nTop Total Price Change")
    sort!(sorted_symbols, by=s -> price_groups[s].total_price_change, rev=true)
    for (i, s) in enumerate(sorted_symbols)
        if i > SHOW_LIMIT
            break
        end
        pg = price_groups[s]
        println(to_string(pg, true))
    end
    
    println("\nTop Relative Price Change")
    sort!(sorted_symbols, by=s -> abs(price_groups[s].relative_price_change), rev=true)
    for (i, s) in enumerate(sorted_symbols)
        if i > SHOW_LIMIT
            break
        end
        pg = price_groups[s]
        println(to_string(pg, true))
    end
    
    println("\nTop Total Volume Change")
    sort!(sorted_symbols, by=s -> price_groups[s].total_volume_change, rev=true)
    for (i, s) in enumerate(sorted_symbols)
        if i > SHOW_LIMIT
            break
        end
        pg = price_groups[s]
        println(to_string(pg, true))
    end
end

function main()
    println("Loading configuration...")
    
    api_config = load_config("api_config.json")
    telegram_config_dict = load_config("telegram_config.json")
    telegram_bot_token = get(telegram_config_dict, "bot_token", "")
    chat_ids_str = get(telegram_config_dict, "chat_ids", "[]")
    
    if !isempty(chat_ids_str)
        try
            telegram_chat_ids = JSON3.read(chat_ids_str, Vector{Int})
        catch
            telegram_chat_ids = Int[]
        end
    end
    
    println("Connecting to Binance WebSocket...")
    
    running = true
    
    task = @async begin
        try
            WebSockets.open(BINANCE_WS_URL) do ws
                @info "WebSocket connected"
                
                while running && isopen(ws)
                    try
                        msg = receive(ws)
                        data = JSON3.read(String(msg), Vector{Dict{String, Any}})
                        process_message(data)
                    catch e
                        if e isa WebSockets.WebSocketClosedError
                            @info "WebSocket closed"
                            break
                        else
                            @warn "WebSocket error" exception=(e, catch_backtrace())
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
        running = false
        println("\nShutting down...")
    end
    
    println("Websocket running. Press Ctrl+C to exit.")
    
    try
        wait(stop_event)
    catch e
        if e isa InterruptException
            println("\nInterrupt received")
        end
    end
end

main()
