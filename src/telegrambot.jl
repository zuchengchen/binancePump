using JSON3

mutable struct TelegramNotifier
    bot_token::String
    chat_ids::Vector{Int}
    enabled::Bool
    lock::ReentrantLock
    
    function TelegramNotifier(bot_token::String, chat_ids::Vector{Int}=Int[])
        new(bot_token, chat_ids, !isempty(chat_ids), ReentrantLock())
    end
end

function send_message(notifier::TelegramNotifier, text::String; parse_mode::String="")::Bool
    if !notifier.enabled
        return false
    end
    
    if isempty(notifier.chat_ids)
        @warn "No chat IDs configured for Telegram notifications"
        return false
    end
    
    success = true
    for chat_id in notifier.chat_ids
        try
            url = "https://api.telegram.org/bot$(notifier.bot_token)/sendMessage"
            params = Dict(
                "chat_id" => chat_id,
                "text" => text
            )
            
            if !isempty(parse_mode)
                params["parse_mode"] = parse_mode
            end
            
            response = HTTP.post(url, 
                               ["Content-Type" => "application/json"], 
                               body=JSON3.write(params))
            
            result = JSON3.read(String(response.body))
            if !get(result, "ok", false)
                @warn "Telegram API error: $(get(result, "description", "Unknown error"))"
                success = false
            end
        catch e
            @warn "Failed to send Telegram message" exception=(e, catch_backtrace())
            success = false
        end
    end
    
    return success
end

function add_chat_id!(notifier::TelegramNotifier, chat_id::Int)
    lock(notifier.lock) do
        if !(chat_id in notifier.chat_ids)
            push!(notifier.chat_ids, chat_id)
            if !notifier.enabled
                notifier.enabled = true
                @info "Telegram notifications enabled with chat_id: $chat_id"
            end
        end
    end
end

function remove_chat_id!(notifier::TelegramNotifier, chat_id::Int)
    lock(notifier.lock) do
        filter!(x -> x != chat_id, notifier.chat_ids)
        if isempty(notifier.chat_ids)
            notifier.enabled = false
            @info "Telegram notifications disabled (no chat IDs)"
        end
    end
end

function is_enabled(notifier::TelegramNotifier)::Bool
    return notifier.enabled
end
