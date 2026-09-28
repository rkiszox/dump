local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local filter = require("./filter")
local sandbox = require("./sandbox")
local deserializer = require("./deserializer")
local encoder = require("./encoder")

local string_format = string.format
local string_gsub = string.gsub
local string_find = string.find
local string_match = string.match
local table_concat = table.concat

local args = process.args
local target_file = args[1] or "C:/Users/plati/Desktop/14.8.lua"
local output_file = args[2] or "output/dump_raw.json"
local output_lua_file = args[3] or "output/dump_constants.lua"

if not fs.isFile(target_file) then
    print("[Error] Target file does not exist: " .. target_file)
    process.exit(1)
end

print("[+] Reading target script: " .. target_file)
local raw_content = fs.readFile(target_file)
print(string_format("[+] File size: %d bytes", #raw_content))

local clean_raw = string_gsub(raw_content, "^%s*getgenv%(%)[^\n]*\n", "")
clean_raw = string_gsub(clean_raw, "^%s*%-%-[^\n]*\n", "")
clean_raw = string_gsub(clean_raw, "%s+$", "")

local vm_code = clean_raw
local bytecode = nil
local is_stage1_packed = false

local v147_patch, v147_count = string_gsub(clean_raw, "c%(C and P and n%(P%)==['\"]function['\"].-return%s*P%(y%);%s*end%)%(%)%(%.*%)%s*;?%s*$", "return {vm_code = M, bytecode = y};end)()")
if v147_count > 0 then
    local ok, res = pcall(function()
        local fn = luau.load(v147_patch)
        return fn()
    end)
    if ok and type(res) == "table" and res.vm_code then
        vm_code = res.vm_code
        bytecode = res.bytecode
        is_stage1_packed = true
        print(string_format("[+] Luraph v14.7 Stage 1 unpacked successfully: VM code %d bytes", #vm_code))
    end
end

if not is_stage1_packed and (string_find(clean_raw, "LPH") or string_find(clean_raw, "return%(function") or string_find(clean_raw, "string%.gsub")) then
    local stage1_patch, stage1_count = string_gsub(
        clean_raw,
        "return%s+([a-zA-Z0-9_]+)%(%s*([a-zA-Z0-9_]+)%s*%);%s*end%)%(%)%(%.*%)%s*;?%s*$",
        function(fn, arg)
            return "return {vm_fn = " .. fn .. ", bytecode = " .. arg .. ", vm_code = Y};end)()"
        end
    )
    if stage1_count > 0 then
        local ok, res = pcall(function()
            local fn = luau.load(stage1_patch)
            return fn()
        end)
        if ok and type(res) == "table" then
            if type(res.vm_code) == "string" then
                vm_code = res.vm_code
                bytecode = res.bytecode
                is_stage1_packed = true
                print(string_format("[+] Luraph Stage 1 unpacked successfully: VM code %d bytes", #vm_code))
            end
        end
    end
end

local entrypoint = string_match(vm_code, "%)%s*:%s*([a-zA-Z0-9_]+)%s*%(") or "c"
print("[+] Entrypoint detected: :" .. entrypoint .. "()")

local clean_vm = string_gsub(vm_code, "%s+$", "")
local stripped_vm_code, strip_count = string_gsub(clean_vm, "%)%s*:%s*[a-zA-Z0-9_]+%s*%b()%s*%b()%s*;?%s*$", ")")
if strip_count == 0 then
    stripped_vm_code, strip_count = string_gsub(clean_vm, "%)%s*:%s*[a-zA-Z0-9_]+%s*%b()%s*;?%s*$", ")")
end
if strip_count == 0 then
    stripped_vm_code, strip_count = string_gsub(clean_vm, "%)%s*:%s*[a-zA-Z0-9_]+%s*;?%s*$", ")")
end
print(string_format("[+] VM table isolated (stripped %d auto-executor call)", strip_count))

local all_captured_protos = {}
local seen_protos = {}

local function register_proto(p: any)
    if type(p) == "table" and not seen_protos[p] then
        seen_protos[p] = true
        all_captured_protos[#all_captured_protos + 1] = p
    end
end

local function traverse_proto_tree(p: any)
    if type(p) ~= "table" then return end
    register_proto(p)
    for k, v in pairs(p) do
        if type(v) == "table" and (k == 5 or k == 6 or k == 8 or k == 9 or k == 11) then
            for _, child in pairs(v) do
                if type(child) == "table" and not seen_protos[child] then
                    traverse_proto_tree(child)
                end
            end
        end
    end
end

local dynamic_captured_strings = {}
local function register_str(s: string)
    if type(s) == "string" and filter.is_clean_constant_string(s) then
        dynamic_captured_strings[s] = (dynamic_captured_strings[s] or 0) + 1
    end
end

local r_env, dynamic_roblox_strings = sandbox.create_roblox_sandbox(register_str)

local load_ok, vm_fn = pcall(function() return luau.load(stripped_vm_code, { environment = r_env }) end)
local vm = nil
local closure_fn = nil

if load_ok then
    if bytecode then
        local ok_run, val = pcall(function() return vm_fn(bytecode) end)
        if ok_run and type(val) == "table" then vm = val end
    else
        local ok_run, val = pcall(function() return vm_fn() end)
        if ok_run and type(val) == "table" then vm = val end
    end
end

if type(vm) == "table" then
    print("[+] Luraph VM table initialized (Phase 1)")
    deserializer.hook_vm_deserializers(vm, register_proto, register_str)
    
    print("[+] Executing Phase 1 VM initialization routine...")
    local ok, res = pcall(function()
        if type(vm[entrypoint]) == "function" then
            return vm[entrypoint](vm)
        elseif type(vm.a) == "function" then
            return vm:a()
        elseif type(vm.x) == "function" then
            return vm:x()
        elseif type(vm.c) == "function" then
            return vm:c()
        elseif type(vm.F) == "function" then
            return vm:F()
        elseif type(vm.o) == "function" then
            return vm:o()
        elseif type(vm.B) == "function" then
            return vm:B()
        elseif type(vm.k_) == "function" then
            return vm:k_()
        end
    end)
    if ok and type(res) == "function" then
        closure_fn = res
    end
    print(string_format("[+] Phase 1 Execution finished (status: %s)", tostring(ok)))
end

local initial_count = #all_captured_protos
local snapshot_initial = {}
for _, p in ipairs(all_captured_protos) do
    snapshot_initial[#snapshot_initial + 1] = p
end

for _, p in ipairs(snapshot_initial) do
    traverse_proto_tree(p)
end

print(string_format("[+] Phase 1 captured %d initial protos -> %d total protos in tree", initial_count, #all_captured_protos))

if closure_fn ~= nil and #all_captured_protos == 0 then
    print("[+] Activating Phase 2 (Roblox Mock Sandbox Execution)...")
    local co = coroutine.create(closure_fn)
    pcall(function() coroutine.resume(co) end)
    
    local roblox_str_count = 0
    for _ in pairs(dynamic_roblox_strings) do roblox_str_count += 1 end
    for _ in pairs(dynamic_captured_strings) do roblox_str_count += 1 end
    print(string_format("[+] Phase 2 Captured %d decrypted constants", roblox_str_count))
end

local proto_output_list = {}
local global_string_map = {}

local function deep_inspect(tbl: any, proto_id: number, str_collector: any, num_collector: any, bool_collector: any, visited: any)
    if not visited then visited = {} end
    local t = type(tbl)
    if t == "string" then
        if filter.is_clean_constant_string(tbl) and #tbl >= 2 then
            str_collector[tbl] = (str_collector[tbl] or 0) + 1
            if not global_string_map[tbl] then
                global_string_map[tbl] = {value = tbl, length = #tbl, count = 0, locations = {}}
            end
            global_string_map[tbl].count += 1
            global_string_map[tbl].locations[#global_string_map[tbl].locations + 1] = tostring(proto_id)
        end
    elseif t == "number" then
        num_collector[tostring(tbl)] = (num_collector[tostring(tbl)] or 0) + 1
    elseif t == "boolean" then
        bool_collector[tostring(tbl)] = (bool_collector[tostring(tbl)] or 0) + 1
    elseif t == "table" then
        if visited[tbl] then return end
        visited[tbl] = true
        for k, v in pairs(tbl) do
            if type(k) == "string" and filter.is_clean_constant_string(k) and #k >= 2 then
                str_collector[k] = (str_collector[k] or 0) + 1
                if not global_string_map[k] then
                    global_string_map[k] = {value = k, length = #k, count = 0, locations = {}}
                end
                global_string_map[k].count += 1
                global_string_map[k].locations[#global_string_map[k].locations + 1] = tostring(proto_id)
            end
            deep_inspect(v, proto_id, str_collector, num_collector, bool_collector, visited)
        end
        local mt = getmetatable(tbl)
        if type(mt) == "table" and not visited[mt] then
            deep_inspect(mt, proto_id, str_collector, num_collector, bool_collector, visited)
        end
    end
end

if #all_captured_protos > 0 then
    for idx, proto in ipairs(all_captured_protos) do
        local p_id = idx - 1
        local p_strings = {}
        local p_numbers = {}
        local p_booleans = {}
        local p_subprotos = {}
        
        local num_insts = (type(proto[2]) == "table" and #proto[2]) or (type(proto[1]) == "table" and #proto[1]) or 0
        local registers = type(proto[8]) == "number" and proto[8] or 0
        local params = type(proto[11]) == "number" and proto[11] or (type(proto[4]) == "number" and proto[4]) or 0
        local varargs = (type(proto[7]) == "table" and #proto[7] > 0) or false
        
        for k, v in pairs(proto) do
            if k ~= 9 and k ~= 8 and k ~= 5 and k ~= 6 and k ~= 2 and k ~= 3 and type(v) == "table" then
                deep_inspect(v, p_id, p_strings, p_numbers, p_booleans, {})
            end
        end
        
        if p_id == 0 then
            for s, c in pairs(dynamic_roblox_strings) do
                if filter.is_clean_constant_string(s) and not p_strings[s] then
                    p_strings[s] = c
                    if not global_string_map[s] then
                        global_string_map[s] = {value = s, length = #s, count = c, locations = {"0"}}
                    end
                end
            end
            for s, c in pairs(dynamic_captured_strings) do
                if filter.is_clean_constant_string(s) and not p_strings[s] then
                    p_strings[s] = c
                    if not global_string_map[s] then
                        global_string_map[s] = {value = s, length = #s, count = c, locations = {"0"}}
                    end
                end
            end
        end
        
        if proto[5] and type(proto[5]) == "table" then
            for k, v in pairs(proto[5]) do
                p_subprotos[#p_subprotos + 1] = {index = tostring(k), target = tostring(v)}
            end
        end
        if proto[6] and type(proto[6]) == "table" then
            for k, v in pairs(proto[6]) do
                p_subprotos[#p_subprotos + 1] = {index = tostring(k), target = tostring(v)}
            end
        end
        if proto[9] and type(proto[9]) == "table" then
            for k, v in pairs(proto[9]) do
                p_subprotos[#p_subprotos + 1] = {index = tostring(k), target = tostring(v)}
            end
        end
        
        local str_list = {}
        for s, c in pairs(p_strings) do
            str_list[#str_list + 1] = {value = s, count = c}
        end
        table.sort(str_list, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.value < b.value
        end)
        
        local num_list = {}
        for n_str, c in pairs(p_numbers) do
            num_list[#num_list + 1] = {value = tonumber(n_str) or n_str, count = c}
        end
        table.sort(num_list, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return tostring(a.value) < tostring(b.value)
        end)
        
        local bool_list = {}
        for b_str, c in pairs(p_booleans) do
            bool_list[#bool_list + 1] = {value = (b_str == "true"), count = c}
        end
        
        proto_output_list[#proto_output_list + 1] = {
            id = p_id,
            num_instructions = num_insts,
            registers = registers,
            num_params = params,
            has_varargs = varargs,
            strings = str_list,
            numbers = num_list,
            booleans = bool_list,
            proto_references = p_subprotos
        }
    end
else
    local str_list = {}
    local added_set = {}
    
    for s, c in pairs(dynamic_roblox_strings) do
        if not added_set[s] and filter.is_clean_constant_string(s) then
            added_set[s] = true
            str_list[#str_list + 1] = {value = s, count = c}
            if not global_string_map[s] then
                global_string_map[s] = {value = s, length = #s, count = c, locations = {"0"}}
            end
        end
    end
    for s, c in pairs(dynamic_captured_strings) do
        if not added_set[s] and filter.is_clean_constant_string(s) then
            added_set[s] = true
            str_list[#str_list + 1] = {value = s, count = c}
            if not global_string_map[s] then
                global_string_map[s] = {value = s, length = #s, count = c, locations = {"0"}}
            end
        end
    end
    
    table.sort(str_list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.value < b.value
    end)
    
    proto_output_list[1] = {
        id = 0,
        num_instructions = 0,
        registers = 0,
        num_params = 0,
        has_varargs = false,
        strings = str_list,
        numbers = {},
        booleans = {},
        proto_references = {}
    }
    print(string_format("[+] Populated %d decrypted strings in Prototype #0", #str_list))
end

local global_strings_list = {}
for s, info in pairs(global_string_map) do
    global_strings_list[#global_strings_list + 1] = info
end
table.sort(global_strings_list, function(a, b)
    if a.count ~= b.count then
        return a.count > b.count
    end
    return a.value < b.value
end)

local final_json = {
    metadata = {
        source_file = target_file,
        total_prototypes = #proto_output_list,
        total_unique_strings = #global_strings_list,
        is_stage1_packed = is_stage1_packed,
        timestamp = os.time(),
        obfuscator = "Luraph"
    },
    strings = global_strings_list,
    prototypes = proto_output_list
}

local function safe_write(path: string, content: string)
    local parent = string_match(path, "^(.*)[/\\][^/\\]+$")
    if parent and #parent > 0 and not fs.isDir(parent) then
        pcall(function() fs.writeDir(parent) end)
    end
    local ok, err = pcall(function() fs.writeFile(path, content) end)
    return ok
end

local json_str = encoder.json_encode(final_json)
if safe_write(output_file, json_str) then
    print(string_format("[+] JSON dump written to: %s", output_file))
end

local lua_file_content = encoder.build_lua_output(proto_output_list)
if safe_write(output_lua_file, lua_file_content) then
    print(string_format("[+] Output constants written to: %s (%d bytes)", output_lua_file, #lua_file_content))
end
