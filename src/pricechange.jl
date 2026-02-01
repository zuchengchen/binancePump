using Dates

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

function is_pump(pc::PriceChange, lim_perc::Float64)::Bool
    return price_change_perc(pc) >= lim_perc
end

function is_dump(pc::PriceChange, lim_perc::Float64)::Bool
    threshold = -abs(lim_perc)
    return price_change_perc(pc) <= threshold
end

function Base.show(io::IO, pc::PriceChange)
    print(io, "PriceChange(symbol=$(pc.symbol), prev_price=$(pc.prev_price), ")
    print(io, "price=$(pc.price), total_trades=$(pc.total_trades), ")
    print(io, "open_price=$(pc.open_price), volume=$(pc.volume), ")
    print(io, "is_printed=$(pc.is_printed), event_time=$(pc.event_time), ")
    print(io, "prev_volume=$(pc.prev_volume))")
end
