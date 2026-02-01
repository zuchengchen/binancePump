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

function to_int(val)::Int
    if isa(val, Int)
        return val
    elseif isa(val, Float64)
        return Int(val)
    else
        return parse(Int, string(val))
    end
end

function to_float64(val)::Float64
    if isa(val, Float64)
        return val
    elseif isa(val, Int)
        return Float64(val)
    else
        return parse(Float64, string(val))
    end
end

function process_message(tickers::Vector{Dict{String, Any}})
    global price_changes, price_groups
    
    for ticker in tickers
        symbol = get(ticker, "s", "")
        
        if !isempty(SHOW_ONLY_PAIR) && !contains(symbol, SHOW_ONLY_PAIR)
            continue
        end
        
        price = to_float64(get(ticker, "c", "0.0"))
        total_trades = to_int(get(ticker, "n", "0"))
        open_price = to_float64(get(ticker, "o", "0.0"))
        volume = to_float64(get(ticker, "v", "0.0"))
        event_time_unix = to_int(get(ticker, "E", "0"))
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
    
    if isempty(price_groups)
        return
    end
    
    sorted_symbols = collect(keys(price_groups))
    
    println("\nTop Ticks")
    sort!(sorted_symbols, by=s -> price_groups[s].tick_count, rev=true)
    for (i, s) in enumerate(sorted_symbols)
        if i > SHOW_LIMIT
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
        if i > SHOW_LIMIT
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
        if i > SHOW_LIMIT
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
        if i > SHOW_LIMIT
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
    println("Loading configuration...")
    
    println("Connecting to Binance WebSocket...")
    
    try
        WebSockets.open(BINANCE_WS_URL) do ws
            println("WebSocket connected to $(BINANCE_WS_URL)")
            println("Websocket running. Press Ctrl+C to exit.")
            
            while true
                try
                    msg = receive(ws)
                    data = JSON3.read(String(msg), Vector{Dict{String, Any}})
                    process_message(data)
                catch e
                    println("\nWebSocket error: $e")
                    break
                end
            end
            
            println("WebSocket disconnected")
        end
    catch e
        println("\nWebSocket connection error: $e")
    end
    
    println("Clean exit complete.")
end

main()
