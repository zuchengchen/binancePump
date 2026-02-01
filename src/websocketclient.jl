using HTTP.WebSockets

mutable struct BinanceWebSocket
    ws::Union{WebSockets.WebSocket, Nothing}
    url::String
    running::Bool
    callbacks::Vector{Function}
    lock::ReentrantLock
    
    function BinanceWebSocket(url::String)
        new(nothing, url, false, Function[], ReentrantLock())
    end
end

function connect!(ws_client::BinanceWebSocket)
    lock(ws_client.lock) do
        ws_client.ws = nothing
    end
    
    task = @async begin
        try
            ws_client.running = true
            WebSockets.open(ws_client.url) do ws
                lock(ws_client.lock) do
                    ws_client.ws = ws
                end
                
                @info "WebSocket connected to $(ws_client.url)"
                
                while ws_client.running && isopen(ws)
                    try
                        msg = receive(ws)
                        for callback in ws_client.callbacks
                            try
                                callback(String(msg))
                            catch e
                                @warn "Callback error" exception=(e, catch_backtrace())
                            end
                        end
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
        finally
            lock(ws_client.lock) do
                ws_client.ws = nothing
            end
            ws_client.running = false
        end
    end
    
    return task
end

function disconnect!(ws_client::BinanceWebSocket)
    ws_client.running = false
    
    lock(ws_client.lock) do
        if ws_client.ws !== nothing && isopen(ws_client.ws)
            try
                close(ws_client.ws)
                @info "WebSocket closed by disconnect!"
            catch e
                @warn "Error closing WebSocket" exception=(e, catch_backtrace())
            end
        end
    end
end

function add_callback!(ws_client::BinanceWebSocket, callback::Function)
    push!(ws_client.callbacks, callback)
end

function is_connected(ws_client::BinanceWebSocket)::Bool
    lock(ws_client.lock) do
        return ws_client.ws !== nothing && isopen(ws_client.ws)
    end
end
