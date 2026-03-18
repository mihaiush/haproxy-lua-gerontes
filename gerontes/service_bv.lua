-- backend value

local function svc(applet)
    local v_old = -1
    local l = applet:getline()
    l = string.gsub(l, '[\r\n]', '')
    l = utils.split(l, ':', 1)
    local cmd = l[1]:lower()
    local bn = l[2] -- backend name
    if B[bn] then
        if cmd == 'get' then
            applet:send('val:' .. B[bn].value .. '\n')
        elseif cmd == 'watch' then
            local q = {['a'] = true, ['t'] = utils.now(), ['q'] = core.queue()}
            table.insert(Q, q)
            while true do
                q.t = utils.now()
                local v = B[bn].value
                if v ~= v_old then
                    applet:send('val:' .. v .. '\n')
                end
                v_old = v
                if q.q:pop_wait() == 'quit' then
                    applet:send('quit\n')
                    break
                end
            end
        else
            applet:send('err:unknown-command\n')
        end
    else
        applet:send('err:unknown-backend\n')
    end
end

local function gc()
    while true do
        -- print_r(Q)
        for i,q in ipairs(Q) do
            if not q.a then
                table.remove(Q, i)
            end
        end
        for i,q in ipairs(Q) do
            if utils.now() - q.t > math.ceil(1.2 * OPT.watchTimeout) then
                q.q:push('quit')
                q.a = false
            end
        end
        core.sleep(OPT.watchGC)
    end
end

return {['svc'] = svc, ['gc'] = gc}

