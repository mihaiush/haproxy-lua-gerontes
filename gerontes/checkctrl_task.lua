local function now()
    local t = core.now()
    return t.sec + t.usec/1000000
end

local function server_worker(target, srvtype)
    local label = srvtype .. '/' .. target -- log label
    label = 'servercheck: ' .. label .. ': '
    
    if OPT.debug then
        utils.log.enable_debug()
    end
    utils.log.info(label .. 'start')

    local v_old = -1
    local err = 0
    local loop_count = 0
    local loop_latency = 0
    local check_latency = 0    
    
    local sleep = 1000 * OPT.sleep
    local s
    local v = 0
    local worker = require('gerontes.srvcheck_' .. srvtype).worker
    local r = 0
    local ok = false
    local t0, t1
    
    while true do
        s = sleep

        t0 = now()        
        ok, r = worker(label, utils.strip_type(target))
        t0 = 1000 * (now() - t0)

        if ok then
            v = r
            err = 0
                if OPT.latencyMetrics then 
                    loop_count = loop_count + 1
                    check_latency = check_latency + t0
                    if loop_count >= OPT.latencyMetrics then
                        utils.log.debug(label .. 'check latency: ' .. check_latency / loop_count)
                        M['server_latency'][target] = check_latency / loop_count
                        loop_count = 0
                        loop_latency = 0
                        check_latency = 0
                    end
                end
        else
            if v_old ~= -1 then
                if err < OPT.softFail then
                    v = v_old
                    err = err + 1
                    utils.log.warning(label .. 'soft-failed: ' .. v .. ' ' .. err .. '/' .. OPT.softFail ..': ' .. r)
                else
                    v = 0
                    s = OPT.failMultiplier * sleep
                    utils.log.error(label .. 'hard-failed' .. ': ' .. r)
                end
            end 
        end
        if v ~= v_old then 
            utils.log.info(label .. v_old .. ' -> ' .. v)
            S[target] = v
            update_servers('task/' .. target)
            v_old = v
        end

        core.msleep(s)
    end -- while
end

return function(target, srvtype)
    core.register_task(server_worker, target, srvtype)
end

