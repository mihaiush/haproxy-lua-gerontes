function task_netcheck(target)
    utils.log.info('start network check: ' .. target)
    local errors = 0
    local sleep = 1000 * opt.sleep
    local to = opt.netTimeout * opt.sleep
    local ip = core.tokenize(target,':')[1]
    local port = core.tokenize(target,':')[2]
    local v
    local s
    local t
    local v_old = 0
    while true do
        s = sleep
        t = core.tcp()
        t:settimeout(to)
        local r = t:connect(ip, port)
        t:close()
        if r then
            v = 1
            errors = 0
        else
            if errors < opt.netSoftFail then
                v = N[target]
                errors = errors + 1
                utils.log.warning('netcheck: ' .. target .. ': soft-failed: ' .. errors .. '/' .. opt.netSoftFail)
            else
                v = 0
                s = opt.failMultiplier * sleep
                utils.log.error('netcheck: ' .. target .. ': hard-failed')
            end
        end
        v_old = N[target]
        N[target] = v
        if not (N[target] == v_old) then
            utils.log.info('netcheck: ' .. target .. ': ' .. v_old .. ' -> ' .. N[target])
            -- sync
        end
        core.msleep(s)
    end
end

