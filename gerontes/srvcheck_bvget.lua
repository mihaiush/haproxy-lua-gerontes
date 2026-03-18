local function worker(label, target)
    local r, ok

    target = utils.split(target,':')

    local tcp = core.tcp()
    tcp:settimeout(math.ceil(OPT.timeout))
    
    ok, r = tcp:connect(target[1], tonumber(target[2]))
    if not ok then
        tcp:close()
        return false, r
    end

    ok, r = tcp:send('get:' .. target[3] .. '\n')
    if not ok then
        tcp:close()
        return false, r
    end

    r, ok = tcp:receive('*l')
    tcp:close()
    if not r then
        return false, ok
    end

    r = utils.split(r, ':', 1)
    if r[1] == 'val' then
        return true, tonumber(r[2])
    end

    return false, r[2]
end

local ctrl = require('gerontes.checkctrl_task')

return function(target)
    ctrl('bvget', target, worker)
end

