return function(applet)
    local r = ''
    local v

    if opt.haproxyMetrics then
        local m = core.httpclient():get{url=opt.haproxyMetrics}
        if m.status == 200 then
            r = r .. '\n' .. m.body .. '\n'
        end
    end

    r = r .. 'gerontes_info{type="' .. opt.type .. '"} 1\n'

    if opt.xCheck then
        r = r .. 'gerontes_xcheck ' .. xcheck .. '\n'
    end

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
        for sn,sd in pairs(core.backends[bn].servers) do
            if sd:get_stats().status == 'no check' then
                v = '1'
            else
                v = '0'
            end
            r = r .. 'gerontes_server_up{server="' .. sn .. '",proxy="' .. bn .. '",xcheck="' .. x .. '"} ' .. v .. '\n'
        end
    end

    applet:set_status(200)
    applet:add_header("content-length", string.len(r))
    applet:add_header("content-type", "text/plain")
    applet:start_response()
    applet:send(r)

    r = nil
end
