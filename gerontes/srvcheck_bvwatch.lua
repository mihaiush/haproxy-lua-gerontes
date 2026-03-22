
local function server_worker(target)
    local label = 'bvwatch/' .. target -- log label
    label = label .. ': '
 
    if OPT.debug then
        utils.log.enable_debug()
    end
    utils.log.info(label .. 'start')

    local t = utils.strip_type(target)
    t = utils.split(t,':')

    local sleep = 1000 * OPT.sleep
    local err = 0

    core.sleep(2) -- wait for servers to start

    while true do
        local r = 'unknown'
        local ok = false
        local s = sleep

        local tcp = core.tcp()
        tcp:settimeout(OPT.timeout)
        local t0 = utils.now()
        utils.log.debug(label .. 'connect')
        ok, r = tcp:connect(t[1], tonumber(t[2]))
        if ok then
            ok, r = tcp:send('watch:' .. t[3] .. '\n')
            if ok then
                t0 = 1000 * (utils.now() - t0)
                M['server_latency'][target] = t0
                utils.log.debug(label .. 'bv latency: ' .. t0)
                
                tcp:settimeout(OPT.watchTimeout)
                while true do
                    r,ok = tcp:receive()
                    if ok == nil then
                        r = utils.split(r, ':', 1)
                        if r[1] == 'val' then
                            set_server(target, tonumber(r[2]))
                        else
                            r = r[2]
                            ok = false
                            break
                        end
                    else
                        r = ok
                        ok = true -- most likely watch timeout
                        s = 1
                        break 
                    end
                end
            end
        end

        tcp:close()

        if not ok then
            if err < OPT.softFail then
                err = err + 1
                utils.log.warning(label .. 'soft-failed: ' .. S[target] .. ' ' .. err .. '/' .. OPT.softFail ..': ' .. r)
            else
                s = OPT.failMultiplier * sleep
                utils.log.error(label .. 'hard-failed' .. ': ' .. r)
                set_server(target, 0)
            end
        end

        core.msleep(s)
    end
end

return function(target)
    core.register_task(server_worker, target)
end

