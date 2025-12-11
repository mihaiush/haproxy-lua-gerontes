return function(applet)
    local r = ''
    local v

    if opt.metrics then
        local m = core.httpclient():get{url=opt.metrics}
        if m.status == 200 then
            r = r .. '\n' .. m.body .. '\n'
        else
        end
    end

    r = r .. 'gerontes_info{type="' .. opt.type .. '",xcheck="' .. tostring(opt.xCheck) .. '"} 1\n'

    for sn,sv in pairs(S) do
        r = r .. 'gerontes_server_value{server="' .. sn .. '"} ' .. tostring(sv) .. '\n'
    end

    for bn,bd in pairs(B) do
        if bd.xcheck then
            v = '1'
        else
            v = '0'
        end
        r = r .. 'gerontes_xcheck{proxy="' .. bn .. '"} ' .. v .. '\n'
        for sn,sd in pairs(core.backends[bn].servers) do
            if sd:get_stats().status == 'no check' then
                v = '1'
            else
                v = '0'
            end
            r = r .. 'gerontes_server_up{server="' .. sn .. '",proxy="' .. bn .. '"} ' .. v .. '\n'
        end
    end

    applet:set_status(200)
    applet:add_header("content-length", string.len(r))
    applet:add_header("content-type", "text/plain")
    applet:start_response()
    applet:send(r)

    r = nil
    v = nil
end
