using Dates

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

function PriceGroup(symbol::String, tick_count::Int, total_price_change::Float64,
                   relative_price_change::Float64, total_volume_change::Float64,
                   last_price::Float64, last_event_time::DateTime,
                   open_price::Float64, volume::Float64)
    return PriceGroup(symbol, tick_count, total_price_change, relative_price_change,
                     total_volume_change, last_price, last_event_time,
                     open_price, volume, false)
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

function Base.getproperty(pg::PriceGroup, key::String)
    if key == "tick_count"
        return getfield(pg, :tick_count)
    elseif key == "total_price_change"
        return getfield(pg, :total_price_change)
    elseif key == "relative_price_change"
        return getfield(pg, :relative_price_change)
    elseif key == "total_volume_change"
        return getfield(pg, :total_volume_change)
    else
        return getfield(pg, Symbol(key))
    end
end
