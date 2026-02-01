using HTTP
using JSON3

const SHOW_ONLY_PAIR = "USDT"
const SHOW_LIMIT = 1
const MIN_PERC = 0.05

const BINANCE_WS_URL = "wss://stream.binance.com:9443/ws/!ticker@arr"

price_changes = PriceChange[]
price_groups = Dict{String, PriceGroup}()
global telegram_notifier = nothing
global ws_client = nothing
global stop_event = Channel{Bool}(1)

function load_config(filename::String)::Dict{String, String}
    try
        config_str = read(filename, String)
        return JSON3.read(config_str, Dict{String, String})
    catch e
        @error "Failed to load config from $filename: $e"
        return Dict{String, String}()
    end
end

function load_telegram_config(filename::String)::Dict{String, Any}
    try
        config_str = read(filename, String)
        return JSON3.read(config_str, Dict{String, Any})
    catch e
        @warn "Failed to load telegram config from $filename: $e"
        return Dict{String, Any}("bot_token" => "", "chat_ids" => Int[])
    end
end

function get_price_groups()::Vector{PriceGroup}
    return collect(values(price_groups))
end

function process_message(tickers::Vector{Dict{String, Any}})
    global price_changes, price_groups, telegram_notifier
    
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
    global price_groups, SHOW_LIMIT, telegram_notifier
    
    any_printed = false
    
    sorted_symbols = collect(keys(price_groups))
    
    sort!(sorted_symbols, by=s -> price_groups[s].tick_count, rev=true)
    any_printed = print_ranking(sorted_symbols, "Top Ticks", SHOW_LIMIT, s -> price_groups[s].tick_count, any_printed)
    
    sort!(sorted_symbols, by=s -> price_groups[s].total_price_change, rev=true)
    any_printed = print_ranking(sorted_symbols, "Top Total Price Change", SHOW_LIMIT, s -> price_groups[s].total_price_change, any_printed)
    
    sort!(sorted_symbols, by=s -> abs(price_groups[s].relative_price_change), rev=true)
    any_printed = print_ranking(sorted_symbols, "Top Relative Price Change", SHOW_LIMIT, s -> abs(price_groups[s].relative_price_change), any_printed)
    
    sort!(sorted_symbols, by=s -> price_groups[s].total_volume_change, rev=true)
    any_printed = print_ranking(sorted_symbols, "Top Total Volume Change", SHOW_LIMIT, s -> price_groups[s].total_volume_change, any_printed)
    
    if any_printed
        println()
        
        if telegram_notifier !== nothing && is_enabled(telegram_notifier)
            send_telegram_summary()
        end
    end
end

function print_ranking(sorted_symbols::Vector{String}, title::String, 
                     limit::Int, key_func::Function, 
                     header_printed::Bool)::Bool
    global price_groups
    
    printed = header_printed
    header_printed = false
    
    for (i, s) in enumerate(sorted_symbols)
        if i > limit
            break
        end
        
        pg = price_groups[s]
        if !pg.is_printed
            if !header_printed
                println(title)
                header_printed = true
            end
            
            println(to_string(pg, true))
            printed = true
        end
    end
    
    return printed
end

function send_telegram_summary()
    global telegram_notifier, price_groups
    
    try
        sorted_symbols = collect(keys(price_groups))
        sort!(sorted_symbols, by=s -> price_groups[s].tick_count, rev=true)
        
        if !isempty(sorted_symbols)
            pg = price_groups[sorted_symbols[1]]
            
            msg = "🔥 *Top PUMP Alert*\n\n" *
                   "Symbol: `$(pg.symbol)`\n" *
                   "Price: $(pg.last_price)\n" *
                   "Ticks: $(pg.tick_count)\n" *
                   "Price Change: $(round(pg.relative_price_change, digits=2))%\n" *
                   "Volume: $(pg.volume)"
            
            send_message(telegram_notifier, msg, parse_mode="Markdown")
        end
    catch e
        @warn "Failed to send Telegram summary" exception=(e, catch_backtrace())
    end
end

function start_monitoring()
    global telegram_notifier, ws_client, stop_event
    
    println("Loading configuration...")
    
    api_config = load_config("api_config.json")
    telegram_config = load_telegram_config("telegram_config.json")
    
    if haskey(telegram_config, "bot_token") && !isempty(telegram_config["bot_token"])
        telegram_notifier = TelegramNotifier(
            telegram_config["bot_token"],
            get(telegram_config, "chat_ids", Int[])
        )
        if is_enabled(telegram_notifier)
            println("Telegram notifications enabled")
        end
    else
        println("Telegram notifications disabled (no bot token)")
    end
    
    ws_client = BinanceWebSocket(BINANCE_WS_URL)
    
    add_callback!(ws_client, function(msg)
        try
            if !isempty(msg)
                data = JSON3.read(msg, Vector{Dict{String, Any}})
                process_message(data)
            end
        catch e
            @warn "Error processing message" exception=(e, catch_backtrace())
        end
    end)
    
    setup_signal_handlers()
    
    println("Connecting to Binance WebSocket...")
    connect!(ws_client)
    
    println("Websocket running. Press Ctrl+C to exit.")
    
    try
        while true
            if !isopen(stop_event) || fetch(stop_event)
                break
            end
            sleep(0.1)
        end
    catch e
        if e isa InterruptException
            println("\nInterrupt received")
        else
            @warn "Error in main loop" exception=(e, catch_backtrace())
        end
    end
end

function stop_monitoring()
    global ws_client, stop_event
    
    println("\nShutting down...")
    
    if ws_client !== nothing
        disconnect!(ws_client)
    end
    
    if isopen(stop_event)
        put!(stop_event, true)
    end
    
    println("Clean exit complete.")
end

function setup_signal_handlers()
    atexit() do
        stop_monitoring()
    end
end

function main()
    start_monitoring()
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
