return function(target, opt)
    local label = opt.type .. '/' .. target -- log label
    
    local main_data = '/dev/shm/main' .. string.gsub(label,'[^%a%d]','_') -- worker output: OK\0R
    local worker_data = '/dev/shm/worker' .. string.gsub(label,'[^%a%d]','_') -- worker output: OK\0R
    label = 'servercheck: ' .. label .. ': '
    
    local msleep = require('time.sleep.msleep')
    local socket = require('socket')

    if opt.debug then
        utils.log.enable_debug()
    end
    utils.log.info(label .. 'start')

    -- move data between forks
    function dump_data(...)
        local r = ''
        for _,v in ipairs({...}) do
            r = r .. tostring(v) .. '\0'
        end
        local f = io.open(main_data, 'w+')
        f:write(r)
        f:close()
    end
    function load_data()
        local f = io.open(main_data, 'r')
        local r = f:read('a')
        f:close()
        local o = {}
        for _,v in ipairs(utils.split(r, '\0')) do
            if v ~= '' then
                table.insert(o, tonumber(v) or v)
            end
        end
        return table.unpack(o)
    end
    
    local function ipc(msg)
        local socket = posix.sys.socket
        local sockfd = socket.socket (socket.AF_UNIX, socket.SOCK_STREAM, 0)
        local r = socket.connect(sockfd, {family = socket.AF_UNIX, path = opt.ipcSock})
        if r == 0 then
	        socket.send(sockfd, msg .. "\n")
            r = socket.recv(sockfd, 1024)
	        socket.shutdown(sockfd, socket.SHUT_RDWR)
        else
            r = 'err'
        end
        return string.gsub(r, '\n$', '')
    end

    local sleep = 1000 * opt.sleep
    local s
    local v = 0
    local v_old = -1
    local err = 0
    local ip = utils.split(target,':')[1]
    local port = utils.split(target,':')[2]
    local worker = require('gerontes.srvcheck_' .. opt.type)
    local r = 0
    local ok = false
    local t
    
    msleep (2 * sleep) -- wait for ipc to start
    if ipc('ping') ~= 'ok' then
        error('ipc check failed')
    end
    
    dump_data(v_old, err)
    

    while true do
        -- local t0 = socket.gettime()
        if posix.fork() == 0 then
            v_old, err = load_data()
            s = sleep

            -- we fork in order to implement timeout
            os.remove(worker_data)
            local fdata
            local pid

            if posix.fork() == 0 then
                -- local t1 = socket.gettime()
                ok, r = worker(label, ip, port, opt)
                -- utils.log.debug(label .. 'check msec: ' .. 1000 * (socket.gettime() - t1))
                -- write fdata        
                fdata = io.open(worker_data, 'w+')
                fdata:write(tostring(ok) .. '\0' .. tostring(r))
                fdata:close()
                os.exit()
            end

            local sw = sleep / 25
            local j = 1000 * opt.timeout / sw
            -- wait for worker to terminate or timeout
            while j > 0 do
                msleep(sw)
                if posix.wait(-1, posix.WNOHANG) ~= 0 then
                    break
                end
                j = j - 1
            end
            -- read data
            fdata = io.open(worker_data, 'r')
            if fdata then
                r = fdata:read('a')
                fdata:close()
                r = utils.split(r, '\0')
                if r[1] == 'true' then
                    -- worker ok
                    ok = true
                    r = tonumber(r[2])
                else
                    -- worker error
                    ok = false
                    r = r[2]
                end
            else
                -- worker timeout
                ok = false
                r = 'timeout'
                -- kill worker
                posix.kill(pid, 9)
                s = 1 -- we already waited timeout
            end

            if ok then
                v = r
                err = 0
            else
                r = tostring(r)
                if v_old ~= -1 then
                    if err < opt.softFail then
                        v = v_old
                        err = err + 1
                        utils.log.warning(label .. 'soft-failed: ' .. v .. ' ' .. err .. '/' .. opt.softFail ..': ' .. r)
                    else
                        v = 0
                        s = opt.failMultiplier * sleep
                        utils.log.error(label .. 'hard-failed' .. ': ' .. r)
                    end
                end 
            end
            -- send ipc message 
            if v ~= v_old then -- or err >= opt.softFail then
                utils.log.info(label .. v_old .. ' -> ' .. v)
                if ipc('server ' .. target .. ' ' .. v) == 'ok' then
                    v_old = v
                end
            end
            -- utils.log.debug(label .. 'loop msec: ' .. 1000 * (socket.gettime() - t0))            

            dump_data(v_old, err)
            msleep(s)
            os.exit()
        end -- fork
        posix.wait()
    end -- while
end

