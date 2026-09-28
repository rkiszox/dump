local function hook_vm_deserializers(vm, register_proto_fn, register_str_fn)
    if type(vm) ~= "table" then return end

    if vm.Hm then
        local orig_Hm = vm.Hm
        vm.Hm = function(self, W, G, X)
            orig_Hm(self, W, G, X)
            if type(X) == "table" and register_proto_fn then
                for _, p in ipairs(X) do register_proto_fn(p) end
            end
        end
    end
    
    if vm.W_ then
        local orig_W_ = vm.W_
        vm.W_ = function(self, j, v, t, z)
            local ret_j, ret_v = orig_W_(self, j, v, t, z)
            if type(z) == "table" and z[62] and type(z[62]) == "function" and register_proto_fn then
                local orig_deser = z[62]
                z[62] = function(...)
                    local proto = orig_deser(...)
                    if type(proto) == "table" then register_proto_fn(proto) end
                    return proto
                end
            end
            return ret_j, ret_v
        end
    end
    
    if vm.mm then
        local orig_mm = vm.mm
        vm.mm = function(self, B, D, Y, I, R, X)
            local ret = {orig_mm(self, B, D, Y, I, R, X)}
            if type(R) == "table" and R[56] and type(R[56]) == "function" and register_proto_fn then
                local orig_deser = R[56]
                R[56] = function(...)
                    local proto = orig_deser(...)
                    if type(proto) == "table" then register_proto_fn(proto) end
                    return proto
                end
            end
            if type(X) == "table" and register_proto_fn then
                for _, p in ipairs(X) do register_proto_fn(p) end
            end
            return unpack(ret)
        end
    end
    
    if vm.tP then
        local orig_tP = vm.tP
        vm.tP = function(self, C, q)
            local ret_q, ret_C = orig_tP(self, C, q)
            if type(ret_q) == "table" and register_proto_fn then register_proto_fn(ret_q) end
            return ret_q, ret_C
        end
    end
    
    if vm.k_ then
        local orig_k_ = vm.k_
        vm.k_ = function(self, C, q, c, u, d, f)
            local ret_c, ret_u, ret_d, ret_f = orig_k_(self, C, q, c, u, d, f)
            if type(C) == "table" and register_proto_fn then
                C[61] = function(proto, chunk)
                    if type(proto) == "table" then register_proto_fn(proto) end
                    return function(...)
                        return proto
                    end
                end
            end
            return ret_c, ret_u, ret_d, ret_f
        end
    end

    if vm.kB then
        local orig_kB = vm.kB
        vm.kB = function(self, Z, z, D, J, A, H)
            if type(Z) == "table" and register_proto_fn then
                register_proto_fn(Z)
            end
            return 1, {function() end}, Z
        end
    end

    if vm.GB then
        local orig_GB = vm.GB
        vm.GB = function(self, A, H, D, J, x, Z)
            local ret = { orig_GB(self, A, H, D, J, x, Z) }
            if type(H) == "table" and type(H[54]) == "function" then
                local orig_54 = H[54]
                H[54] = function(proto, ...)
                    if type(proto) == "table" and register_proto_fn then
                        register_proto_fn(proto)
                    end
                    return function() end
                end
            end
            return unpack(ret)
        end
    end

    if vm.hg then
        local orig_hg = vm.hg
        vm.hg = function(U, p1, w, D, E)
            local ret_D, ret_E = orig_hg(U, p1, w, D, E)
            if type(ret_E) == "string" and register_str_fn then
                register_str_fn(ret_E)
            end
            return ret_D, ret_E
        end
    end

    if vm.k then
        local orig_k = vm.k
        vm.k = function(self, E, J, w)
            if type(w) == "table" then
                setmetatable(w, {
                    __newindex = function(t, k, v)
                        if (k == 29 or k == 0x1d) and type(v) == "function" then
                            local orig_reader = v
                            rawset(t, k, function(buf, key_state, len_or_id)
                                local res_str = orig_reader(buf, key_state, len_or_id)
                                if type(res_str) == "string" and register_str_fn then
                                    register_str_fn(res_str)
                                end
                                return res_str
                            end)
                        elseif (k == 62 or k == 0x3e) and type(v) == "function" and register_proto_fn then
                            local orig_proto_deser = v
                            rawset(t, k, function(...)
                                local proto_res = orig_proto_deser(...)
                                if type(proto_res) == "table" then
                                    register_proto_fn(proto_res)
                                end
                                return proto_res
                            end)
                        else
                            rawset(t, k, v)
                        end
                    end
                })
            end
            return orig_k(self, E, J, w)
        end
    end
end

return {
    hook_vm_deserializers = hook_vm_deserializers
}
