local string_byte = string.byte
local string_find = string.find
local string_match = string.match
local string_sub = string.sub

local function is_ascii_art(s: string): boolean
    if string_find(s, "@@@") or string_find(s, "%%@&") or string_find(s, "#@%%") or string_find(s, "%(@@") or string_find(s, "///") or string_find(s, "%*%%") or string_find(s, "@%%%(%*") then
        return true
    end
    if string_find(s, "    ") and (string_find(s, "@") or string_find(s, "#") or string_find(s, "%%") or string_find(s, "/")) then
        return true
    end
    if #s > 40 and (string_find(s, "\n") or string_find(s, "\r")) then
        local special_chars = 0
        for i = 1, #s do
            local b = string_byte(s, i)
            if b == 64 or b == 37 or b == 38 or b == 35 or b == 42 or b == 47 or b == 92 or b == 40 or b == 41 or b == 61 or b == 46 or b == 44 then
                special_chars += 1
            end
        end
        if special_chars > 6 then
            return true
        end
    end
    return false
end

local function is_clean_constant_string(s: string): boolean
    if type(s) ~= "string" then return false end
    local len = #s
    if len < 2 or len > 500 then return false end
    if is_ascii_art(s) then return false end
    
    if len >= 4 and (string_sub(s, 1, 4) == "LPH?" or string_sub(s, 1, 4) == "LPH!" or string_sub(s, 1, 4) == "LPH+" or string_sub(s, 1, 4) == "LPH-") then
        return false
    end
    
    for i = 1, len do
        local b = string_byte(s, i)
        if b < 32 and b ~= 9 and b ~= 10 and b ~= 13 then
            return false
        end
        if b > 126 then
            return false
        end
    end
    
    if string_find(s, "^%s+$") then
        return false
    end
    
    if string_find(s, "\n") or string_find(s, "\r") then
        if string_find(s, "%[%d+%]") or string_find(s, "%-%-") or string_find(s, "%b{}") or string_find(s, "return%s+{") or string_find(s, "strings%s*=") or string_find(s, "function%s*%(") or string_find(s, "setfenv") or string_find(s, "setmetatable") then
            return false
        end
    end

    if string_find(s, "setfenv%(function") or string_find(s, "LPH_NO_UPVALUES") or string_find(s, "%(%?%d+%)[%:\r\n]") or string_find(s, "^=%[C%]$") or string_find(s, "^%[C%]$") then
        return false
    end
    
    if len == 2 then
        if s == "==" or s == "~=" or s == ">=" or s == "<=" or s == ".." or s == "::" or s == "%s" or s == "%d" or s == "%w" or s == "%a" or s == "%p" or s == "\\n" or s == "\\t" or s == "\\r" then
            return true
        end
        if s == "if" or s == "do" or s == "in" or s == "or" or s == "id" or s == "ip" or s == "os" or s == "to" or s == "fn" or s == "ui" or s == "ok" or s == "go" or s == "me" or s == "my" or s == "no" or s == "on" or s == "up" or s == "at" or s == "by" or s == "as" or s == "is" or s == "it" or s == "he" or s == "we" or s == "am" or s == "an" then
            return true
        end
        return false
    end

    if string_match(s, "^https?://[%w%-%._~:/?#%[%]@!$&'()*+,;=]+$") or string_match(s, "^rbxassetid://%d+$") or string_match(s, "^rbxasset://[%w%-_/%.]+$") or string_match(s, "^discord%.gg/[%w]+$") then
        return true
    end

    if string_match(s, "^%%[%-%+ #0]*%d*%.?%d*[cdeEfgGiouXxsqp%%]$") then
        return true
    end

    if string_match(s, "^%.[a-zA-Z0-9]+$") then
        local ext = string_sub(s, 2):lower()
        if ext == "lua" or ext == "luau" or ext == "txt" or ext == "json" or ext == "png" or ext == "jpg" or ext == "rbxm" or ext == "rbxmx" or ext == "mp3" or ext == "ogg" then
            return true
        end
        return false
    end

    if string_find(s, " ") then
        local letters, digits, spaces, punct = 0, 0, 0, 0
        for i = 1, len do
            local b = string_byte(s, i)
            if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
                letters += 1
            elseif b >= 48 and b <= 57 then
                digits += 1
            elseif b == 32 then
                spaces += 1
            elseif b == 46 or b == 44 or b == 58 or b == 59 or b == 33 or b == 63 or b == 45 or b == 95 or b == 40 or b == 41 or b == 34 or b == 39 or b == 47 then
                punct += 1
            else
                return false
            end
        end
        if (letters + digits + spaces) >= (len * 0.7) and letters >= 3 then
            return true
        end
        return false
    end

    if string_find(s, "[%?%!,;:%=%\'%\"%(%)%[%]%{%}%/\\%*%%%$%#%@%&%^%~%`%+]") then
        return false
    end

    if string_match(s, "^v?%d+%.%d+[%d%.%w%-_]*$") then
        return true
    end

    if len == 3 then
        if string_match(s, "^[a-z][a-z][a-z]$") then
            return true
        end
        if s == "FPS" or s == "RGB" or s == "HSV" or s == "URL" or s == "API" or s == "GUI" or s == "HUD" or s == "CFM" or s == "POS" or s == "ROT" or s == "UID" or s == "PID" or s == "SDK" or s == "PNG" or s == "JPG" or s == "MD5" or s == "SHA" or s == "HEX" or s == "MAX" or s == "MIN" or s == "RAW" or s == "SET" or s == "GET" or s == "ERR" or s == "MSG" or s == "LOG" or s == "APP" or s == "CFG" then
            return true
        end
        return false
    end

    if len == 4 then
        if string_match(s, "^[A-Z][a-z][A-Z]") or string_match(s, "^[a-z][A-Z][A-Z]") or string_match(s, "%d") then
            if not (s == "C3" or s == "V2" or s == "V3" or s == "u16" or s == "u32" or s == "i16" or s == "i32" or s == "utf8") then
                return false
            end
        end
        if string_match(s, "^[a-z]+$") or string_match(s, "^[A-Z][a-z][a-z][a-z]$") or string_match(s, "^[A-Z]+$") then
            return true
        end
        return false
    end

    if string_match(s, "^[A-Z0-9_]+$") and string_find(s, "_") then
        return true
    end

    if string_match(s, "^[a-zA-Z_][a-zA-Z0-9_]*$") then
        local transitions = 0
        for i = 1, len - 1 do
            local b1 = string_byte(s, i)
            local b2 = string_byte(s, i + 1)
            local is_lower1 = (b1 >= 97 and b1 <= 122)
            local is_upper2 = (b2 >= 65 and b2 <= 90)
            local is_digit1 = (b1 >= 48 and b1 <= 57)
            local is_digit2 = (b2 >= 48 and b2 <= 57)
            if (is_lower1 and is_upper2) or (is_lower1 and is_digit2) or (is_digit1 and is_upper2) then
                transitions += 1
            end
        end
        if transitions > (len / 2.5) then
            return false
        end
        return true
    end

    return false
end

local function is_garbage_cipher_string(s: string): boolean
    return not is_clean_constant_string(s)
end

return {
    is_ascii_art = is_ascii_art,
    is_clean_constant_string = is_clean_constant_string,
    is_garbage_cipher_string = is_garbage_cipher_string
}
