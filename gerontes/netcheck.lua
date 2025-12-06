return function(target)
    utils.log.info('start network check: ' .. target)
    local ip = utils.split(target,':')[1]
    local port = utils.split(target,':')[2]
    local errors = 0
    local sleep = 1000 * opt.sleep
    local to = opt.netTimeout * opt.sleep
    local v = 0
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
                v = v_old
                errors = errors + 1
                utils.log.warning('netcheck: ' .. target .. ': soft-failed: ' .. v .. ' ' .. errors .. '/' .. opt.netSoftFail)
            else
                v = 0
                s = opt.failMultiplier * sleep
                utils.log.error('netcheck: ' .. target .. ': hard-failed')
            end
        end
        if v ~= v_old then
            utils.log.info('netcheck: ' .. target .. ': ' .. v_old .. ' -> ' .. v)
            N[target] = v
            update_servers()
            v_old = v
        end
        core.msleep(s)
    end
end

