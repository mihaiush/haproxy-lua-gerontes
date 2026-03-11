local json = require('lunajson')

local function now()
    local t = core.now()
    return t.sec + t.usec/1000000
end

local function server_worker(srvtype, target, worker, apicall)
    local label = srvtype .. '/' .. target -- log label
    label = 'servercheck: ' .. label .. ': '
 
    if OPT.debug then
        utils.log.enable_debug()
    end
    utils.log.info(label .. 'start')

    apicall = apicall .. '&resourceVersion=0&watch=true'
    utils.log.debug(label .. 'api call: ' .. apicall)

    local request = 'GET ' .. apicall .. ' HTTP/1.1\r\n' ..
                    'Host: 127.0.0.1:8082\r\n' ..
                    '\r\n'

    local sleep = 1000 * OPT.sleep
    local connect_to = math.ceil(OPT.timeout)
    local watch_to = 600 
    local v = 0
    local v_old = -1
    local err = 0
   
    local function update()
        if v ~= v_old then
            utils.log.info(label .. v_old .. ' -> ' .. v)
            S[target] = v
            update_servers('srvcheck/' .. target)
            v_old = v
        end
    end
 
    while true do
        local r = 'unknown'
        local ok = false
        local data
        local s = sleep

        update() -- we needed here for -1 -> 0 

        local tcp = core.tcp()
        tcp:settimeout(connect_to)
        local t0 = now()
        ok, r = tcp:connect('127.0.0.1', 8082)
        if ok then
            ok, r = tcp:send(request)
            if ok then
                local r_code, r_text, chunked

                -- read headers
                while true do
                    data, ok = tcp:receive('*l')
                    if ok == nil then
                        data = data:lower()
                        ok = true
                    else
                        r = data
                        ok = false
                        break
                    end
                    if not r_code then
                        data = utils.split(data, ' ')
                        r_code = tonumber(data[2])
                        r_text = data[3]
                    elseif data == 'transfer-encoding: chunked' then
                        chunked = true
                    end
                    if data == '' then break end -- empty line, end of headers
                end

                -- check headers
                if ok then
                    if r_code ~= 200 then
                        r = r_code .. '/' .. r_text
                        ok = false 
                    elseif not chunked then
                        r = 'not chunked'
                        ok = false
                    end
                end

                -- read events
                if ok then
                    t0 = 1000 * (now() - t0)
                    M['server_latency'][target] = t0
                
                    tcp:settimeout(watch_to)
                    while true do
                        -- read chunk size
                        while true do
                            -- loop until no blank line
                            data, ok = tcp:receive('*l')
                            if ok == nil then
                                if data ~= '' then
                                    data = tonumber(data,16)
                                    ok = true
                                    break
                                end
                            else
                                data = nil
                                r = ok
                                ok = true -- most likely watch timeout
                                break
                            end
                        end
                        if data == nil then
                            break
                        end
                        -- read chunk
                        data, ok = tcp:receive(data)
                        if ok == nil then
                            ok, r = pcall(json.decode, data)
                            if ok then
                                ok, r = worker(label, r)
                            end
                            if ok then
                                err = 0
                                v = r
                                update()
                            else
                                break 
                            end
                        else
                            r = ok
                            ok = false
                            break
                        end
                    end
                end
                
            end
        end

        tcp:close()

        if not ok then
            if err < OPT.softFail then
                v = v_old
                err = err + 1
                utils.log.warning(label .. 'soft-failed: ' .. v .. ' ' .. err .. '/' .. OPT.softFail ..': ' .. r)
            else
                v = 0
                s = OPT.failMultiplier * sleep
                utils.log.error(label .. 'hard-failed' .. ': ' .. r)
                update()
            end
        end

        core.msleep(s)
    end -- while
end

return function(srvtype, target, worker, apicall)
    core.register_task(server_worker, srvtype, target, worker, apicall)
end

