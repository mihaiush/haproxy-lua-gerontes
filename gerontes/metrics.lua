local function metrics()
    local r = STATIC_METRICS
    local v,x

    if OPT.haproxyMetrics then
        local m = core.httpclient():get{url=OPT.haproxyMetrics}
        if m.status == 200 then
            r = r .. '\n' .. m.body .. '\n'
        end
        m = nil
    end

    r = r .. 'gerontes_info{type="' .. OPT.type .. '"} 1\n'

    if OPT.xCheck then
        x = 'on'
    else
        x = 'off'
    end
    r = r .. 'gerontes_xcheck {xcheck="' .. x .. '"} ' .. xcheck .. '\n'

    for sn,sv in pairs(S) do
        r = r .. 'gerontes_server_value{server="' .. sn .. '"} ' .. tostring(sv) .. '\n'
        if M['loop_latency'][sn] then
            r = r .. 'gerontes_loop_latency_msec{server="' .. sn .. '"} ' .. tostring(M['loop_latency'][sn]) .. '\n'
        end
        if M['server_latency'][sn] then
            r = r .. 'gerontes_server_latency_msec{server="' .. sn .. '"} ' .. tostring(M['server_latency'][sn]) .. '\n'
        end
    end

    for bn,bd in pairs(B) do
        if bd.xcheck then
            x = 'on'
        else
            x = 'off'
        end
        r = r .. 'gerontes_proxy_value{proxy="' .. bn .. '",xcheck="' .. x .. '"} ' .. bd.value .. '\n'
        for sn,sd in pairs(core.backends[bn].servers) do
            if sd:get_stats().status == 'no check' then
                v = '1'
            else
                v = '0'
            end
            r = r .. 'gerontes_server_up{server="' .. sn .. '",proxy="' .. bn .. '",xcheck="' .. x .. '"} ' .. v .. '\n'
        end
    end

    return r
end

local function query(qs)
    qs = utils.parse_args({ ['t']='_', ['k']='_'}, qs, '=', '&')
    local r
    -- type
    if qs.t == 'p' then
        -- proxy (backend)
        r = tostring(B[qs.k].value)
    elseif qs.t == 's' then
        -- server
        r = tostring(S[qs.k])
    end
    return r
end

return function(applet)
    local r
    local rc

    if applet.qs == nil or applet.qs == '' then
        r = metrics()
    else
        r = query(applet.qs)
    end

    if r then
        rc = 200
    else
        rc = 500
        r = 'Empty response'
    end

    applet:set_status(rc)
    applet:add_header("content-length", string.len(r))
    applet:add_header("content-type", "text/plain")
    applet:start_response()
    applet:send(r)

    r = nil
end
