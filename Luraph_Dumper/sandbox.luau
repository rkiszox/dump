local luau = require("@lune/luau")

local function create_roblox_sandbox(record_fn)
    local dynamic_strings = {}
    
    local function record_str(s)
        if type(s) == "string" and #s >= 2 then
            dynamic_strings[s] = (dynamic_strings[s] or 0) + 1
            if record_fn then record_fn(s) end
        end
    end

    local function mock_object(name)
        local obj = {}
        setmetatable(obj, {
            __index = function(self, key)
                record_str(key)
                local sk = tostring(key)
                if sk == "GetService" then
                    return function(self, sname)
                        record_str(sname)
                        return mock_object(sname)
                    end
                elseif sk == "FindFirstChild" or sk == "WaitForChild" or sk == "FindFirstChildOfClass" then
                    return function(self, sname)
                        record_str(sname)
                        return mock_object(tostring(sname))
                    end
                elseif sk == "Connect" or sk == "Once" then
                    return function(self, fn)
                        return mock_object("Connection")
                    end
                elseif sk == "GetChildren" or sk == "GetDescendants" or sk == "GetPlayers" then
                    return function() return {mock_object("Player")} end
                elseif sk == "GetPlayerByUserId" then
                    return function(self, uid)
                        return mock_object("Player")
                    end
                elseif sk == "GenerateGUID" then
                    return function(self, b)
                        return "00000000-0000-0000-0000-000000000000"
                    end
                elseif sk == "Position" or sk == "Size" or sk == "Velocity" or sk == "RotVelocity" or sk == "Unit" or sk == "Magnitude" or sk == "X" or sk == "Y" or sk == "Z" then
                    return 0
                elseif sk == "PlaceId" or sk == "GameId" or sk == "UserId" or sk == "CreatorId" or sk == "Health" or sk == "MaxHealth" or sk == "WalkSpeed" or sk == "JumpPower" then
                    return 100
                elseif sk == "JobId" then
                    return "Job-12345"
                elseif sk == "Name" or sk == "ClassName" then
                    return name or "Mock"
                elseif sk == "Parent" or sk == "Character" or sk == "CharacterAdded" or sk == "LocalPlayer" or sk == "Terrain" then
                    return mock_object(sk)
                elseif sk == "Wait" then
                    return function() return mock_object("Waited") end
                elseif sk == "IsA" then
                    return function(self, c) return true end
                elseif sk == "Destroy" or sk == "Clone" then
                    return function() return mock_object("Cloned") end
                end
                return mock_object(sk)
            end,
            __newindex = function(self, key, val)
                record_str(key)
                if type(val) == "string" then record_str(val) end
            end,
            __call = function(self, ...)
                local call_args = {...}
                for _, a in ipairs(call_args) do
                    if type(a) == "string" then record_str(a) end
                end
                return mock_object("CallResult")
            end,
            __tostring = function(self) return name or "Mock" end,
            __concat = function(a, b) return tostring(a) .. tostring(b) end,
            __add = function(a, b) return 0 end,
            __sub = function(a, b) return 0 end,
            __mul = function(a, b) return 0 end,
            __div = function(a, b) return 0 end,
            __mod = function(a, b) return 0 end,
            __pow = function(a, b) return 0 end,
            __unm = function(a) return 0 end,
            __len = function(a) return 0 end,
            __eq = function(a, b) return false end,
            __lt = function(a, b) return false end,
            __le = function(a, b) return true end
        })
        return obj
    end

    local function mock_vector()
        local v = {X = 0, Y = 0, Z = 0, Unit = 0, Magnitude = 0}
        setmetatable(v, {
            __index = function(self, key)
                record_str(key)
                if key == "Unit" then return mock_vector() end
                if key == "Magnitude" or key == "X" or key == "Y" or key == "Z" then return 1 end
                return mock_vector()
            end,
            __add = function(a, b) return mock_vector() end,
            __sub = function(a, b) return mock_vector() end,
            __mul = function(a, b) return mock_vector() end,
            __div = function(a, b) return mock_vector() end,
            __unm = function(a) return mock_vector() end,
            __len = function(a) return 0 end,
            __eq = function(a, b) return false end,
            __lt = function(a, b) return false end,
            __le = function(a, b) return true end,
            __tostring = function() return "0, 0, 0" end
        })
        return v
    end

    local r_env = {}
    for k, v in pairs(_G) do r_env[k] = v end

    r_env.game = mock_object("game")
    r_env.workspace = mock_object("workspace")
    r_env.script = mock_object("script")
    r_env.Enum = mock_object("Enum")
    r_env.Instance = {
        new = function(cls, ...)
            record_str("Instance")
            record_str("new")
            record_str(cls)
            return mock_object(cls)
        end
    }
    r_env.Vector2 = {
        new = function(...)
            record_str("Vector2")
            record_str("new")
            return mock_vector()
        end,
        zero = mock_vector(),
        one = mock_vector()
    }
    r_env.Vector3 = {
        new = function(...)
            record_str("Vector3")
            record_str("new")
            return mock_vector()
        end,
        zero = mock_vector(),
        one = mock_vector()
    }
    r_env.CFrame = {
        new = function(...)
            record_str("CFrame")
            record_str("new")
            return mock_object("CFrame")
        end,
        Angles = function(...) return mock_object("CFrame.Angles") end,
        identity = mock_object("CFrame.identity")
    }
    r_env.Color3 = {
        new = function(...)
            record_str("Color3")
            record_str("new")
            return mock_object("Color3")
        end,
        fromRGB = function(...)
            record_str("Color3")
            record_str("fromRGB")
            return mock_object("Color3")
        end,
        fromHSV = function(...)
            record_str("Color3")
            record_str("fromHSV")
            return mock_object("Color3")
        end
    }
    r_env.UDim = {
        new = function(...)
            record_str("UDim")
            record_str("new")
            return mock_object("UDim")
        end
    }
    r_env.UDim2 = {
        new = function(...)
            record_str("UDim2")
            record_str("new")
            return mock_object("UDim2")
        end,
        fromScale = function(...) return mock_object("UDim2") end,
        fromOffset = function(...) return mock_object("UDim2") end
    }
    r_env.Path2DControlPoint = {
        new = function(...)
            record_str("Path2DControlPoint")
            record_str("new")
            return mock_object("Path2DControlPoint")
        end
    }
    r_env.TweenInfo = {
        new = function(...)
            record_str("TweenInfo")
            record_str("new")
            return mock_object("TweenInfo")
        end
    }
    r_env.Ray = {
        new = function(...)
            record_str("Ray")
            record_str("new")
            return mock_object("Ray")
        end
    }
    r_env.RaycastParams = {
        new = function(...)
            record_str("RaycastParams")
            record_str("new")
            return mock_object("RaycastParams")
        end
    }
    r_env.OverlapParams = {
        new = function(...)
            record_str("OverlapParams")
            record_str("new")
            return mock_object("OverlapParams")
        end
    }
    r_env.Random = {
        new = function(...)
            record_str("Random")
            record_str("new")
            return mock_object("Random")
        end
    }
    local wait_count = 0
    r_env.task = {
        spawn = function(f, ...)
            if type(f) == "function" then pcall(f, ...) end
        end,
        delay = function(t, f, ...)
            if type(f) == "function" then pcall(f, ...) end
        end,
        defer = function(f, ...)
            if type(f) == "function" then pcall(f, ...) end
        end,
        wait = function()
            wait_count += 1
            if wait_count > 20 then error("SANDBOX_LOOP_LIMIT") end
            return 0
        end,
        cancel = function() end
    }
    r_env.wait = function()
        wait_count += 1
        if wait_count > 20 then error("SANDBOX_LOOP_LIMIT") end
        return 0
    end
    r_env.tick = function() return 1000.0 end
    r_env.time = function() return 100.0 end
    r_env.elapsedTime = function() return 10.0 end
    r_env.os = {
        time = function() return 1700000000 end,
        clock = function() return 100.0 end,
        date = os.date,
        difftime = os.difftime
    }
    r_env.math = math
    r_env.table = table
    r_env.string = string
    r_env.bit32 = bit32
    r_env.buffer = buffer
    r_env.utf8 = utf8
    r_env.debug = {
        traceback = function(...) return "" end,
        getinfo = function(...) return {source = "", what = "Lua", name = ""} end
    }
    r_env.gethui = function()
        record_str("gethui")
        return mock_object("hui")
    end
    r_env.WebSocket = {
        connect = function(url, ...)
            record_str("WebSocket")
            record_str("connect")
            record_str(url)
            return mock_object("WebSocket")
        end
    }
    r_env.warn = function(...)
        record_str("warn")
        for _, a in ipairs({...}) do
            if type(a) == "string" then record_str(a) end
        end
    end
    r_env.print = function(...)
        for _, a in ipairs({...}) do
            if type(a) == "string" then record_str(a) end
        end
    end
    r_env.pcall = function(f, ...)
        record_str("pcall")
        if type(f) == "function" then return pcall(f, ...) end
        return false
    end
    r_env.xpcall = function(f, h, ...)
        record_str("xpcall")
        if type(f) == "function" then return pcall(f, ...) end
        return false
    end
    r_env.tonumber = function(v, ...)
        record_str("tonumber")
        if type(v) == "string" then record_str(v) end
        return tonumber(v, ...)
    end
    r_env.tostring = function(v)
        record_str("tostring")
        return tostring(v)
    end
    r_env.type = function(v)
        record_str("type")
        return type(v)
    end
    r_env.typeof = function(v)
        record_str("typeof")
        if type(v) == "table" and getmetatable(v) then
            return tostring(v)
        end
        return type(v)
    end
    r_env.loadstring = function(s)
        record_str("loadstring")
        if type(s) == "string" then
            record_str(s)
            local ok_compile, loaded_fn = pcall(function()
                return luau.load(s, { environment = r_env })
            end)
            if ok_compile and type(loaded_fn) == "function" then
                return loaded_fn
            end
        end
        return function() return mock_object("loadstring_res") end
    end
    r_env.islclosure = function(f) return true end
    r_env.iscclosure = function(f) return false end
    r_env.identifyexecutor = function() return "LuraphDumper", "1.0" end
    r_env.getgenv = function() return r_env end
    r_env.getrenv = function() return r_env end
    r_env.getfenv = function() return r_env end
    r_env.setfenv = function(fn, e) return fn end

    setmetatable(r_env, {
        __index = function(self, k)
            record_str(k)
            return mock_object(tostring(k))
        end
    })

    return r_env, dynamic_strings
end

return {
    create_roblox_sandbox = create_roblox_sandbox
}
