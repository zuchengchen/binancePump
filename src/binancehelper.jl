using HTTP
using JSON3
using Dates
using SHA

const BINANCE_API_URL = "https://api.binance.com"

function unix2datetime(unix_ms::Int)::DateTime
    unix_sec = unix_ms ÷ 1000
    ms_remainder = unix_ms % 1000
    return Dates.unix2datetime(unix_sec) + Dates.Millisecond(ms_remainder)
end

function datetime2unix(dt::DateTime)::Int
    unix_sec = Dates.datetime2unix(dt)
    return Int(unix_sec * 1000)
end

function interval_to_milliseconds(interval::String)::Union{Int, Nothing}
    seconds_per_unit = Dict(
        "m" => 60,
        "h" => 60 * 60,
        "d" => 24 * 60 * 60,
        "w" => 7 * 24 * 60 * 60
    )
    
    if isempty(interval) || length(interval) < 2
        return nothing
    end
    
    unit = String(interval[end])
    if haskey(seconds_per_unit, unit)
        try
            num_str = String(interval[1:end-1])
            num = parse(Int, num_str)
            return num * seconds_per_unit[unit] * 1000
        catch
            return nothing
        end
    end
    return nothing
end

function get_historical_klines(symbol::String, interval::String,
                               start_str::String, end_str::String="";
                               api_key::String="", api_secret::String="")
    output_data = Vector{Vector{Any}}()
    limit = 500
    
    timeframe = interval_to_milliseconds(interval)
    if timeframe === nothing
        @error "Invalid interval: $interval"
        return output_data
    end
    
    start_ts = datetime2unix(parse_date_string(start_str))
    end_ts = isempty(end_str) ? nothing : datetime2unix(parse_date_string(end_str))
    
    idx = 0
    symbol_existed = false
    
    while true
        params = Dict(
            "symbol" => uppercase(symbol),
            "interval" => interval,
            "limit" => limit,
            "startTime" => start_ts
        )
        
        if end_ts !== nothing
            params["endTime"] = end_ts
        end
        
        try
            url = build_url("/api/v3/klines", params, api_key, api_secret)
            response = HTTP.get(url)
            temp_data = JSON3.read(String(response.body), Vector{Vector{Any}})
            
            if !symbol_existed && !isempty(temp_data)
                symbol_existed = true
            end
            
            if symbol_existed
                append!(output_data, temp_data)
                
                if !isempty(temp_data)
                    last_time = temp_data[end][1]
                    start_ts = last_time + timeframe
                else
                    break
                end
            else
                start_ts += timeframe
            end
        catch e
            @warn "Error fetching klines: $e"
            break
        end
        
        idx += 1
        if !isempty(temp_data) && length(temp_data) < limit
            break
        end
        
        if idx % 3 == 0
            sleep(1)
        end
    end
    
    return output_data
end

function parse_date_string(date_str::String)::DateTime
    try
        return Dates.DateTime(date_str, "yyyy-mm-dd HH:MM:SS")
    catch
        try
            return Dates.DateTime(date_str, "yyyy-mm-ddTHH:MM:SS")
        catch
            try
                now = Dates.now()
                if occursin("ago", lowercase(date_str))
                    if occursin("hour", lowercase(date_str))
                        hours_ago = parse(Int, match(r"(\d+)\s*hour", lowercase(date_str)).captures[1])
                        return now - Dates.Hour(hours_ago)
                    elseif occursin("minute", lowercase(date_str))
                        mins_ago = parse(Int, match(r"(\d+)\s*minute", lowercase(date_str)).captures[1])
                        return now - Dates.Minute(mins_ago)
                    elseif occursin("day", lowercase(date_str))
                        days_ago = parse(Int, match(r"(\d+)\s*day", lowercase(date_str)).captures[1])
                        return now - Dates.Day(days_ago)
                    end
                end
                return now
            catch
                return Dates.now()
            end
        end
    end
end

function build_url(endpoint::String, params::Dict{String, Any},
                 api_key::String="", api_secret::String="")::String
    url = BINANCE_API_URL * endpoint
    query_parts = String[]
    
    for (k, v) in params
        push!(query_parts, "$k=$v")
    end
    
    if !isempty(api_key)
        push!(query_parts, "timestamp=$(datetime2unix(Dates.now()))")
        push!(query_parts, "signature=$(generate_signature(api_secret, join(query_parts, "&")))")
    end
    
    if !isempty(query_parts)
        url *= "?" * join(query_parts, "&")
    end
    
    return url
end

function generate_signature(secret::String, query_string::String)::String
    using SHA
    return bytes2hex(SHA.hmac(SHA256, secret, query_string))
end
