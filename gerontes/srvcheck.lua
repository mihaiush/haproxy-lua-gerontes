return function(target, opt)
    local label = opt.type .. '/' .. target
    
    local worker_data = '/dev/shm/' .. string.gsub(label,'[^%a%d]','_') -- worker output: OK\0R
    local worker_pid = worker_data .. '.pid' -- worker pid: PID 
    worker_data = worker_data .. '.data'
    
    local msleep = require('time.sleep.msleep')

    if opt.debug then
        utils.log.enable_debug()
    end
    utils.log.info('start server check: ' .. label)

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
    local checks_total = 0
    local checks_usec = 0
    
    msleep (2 * sleep) -- wait for ipc to start
    while ipc('ping') ~= 'ok' do
        utils.log.error('servercheck: ' .. label .. ': ipc check failed')
        msleep(sleep)
    end
    
    while true do
        s = sleep

        -- we fork in order to implement timeout
        -- fork twice to detach from main process
        os.remove(worker_data)
        os.remove(worker_pid)
        local fdata
        local fpid
        local pid
        
        if posix.fork() == 0 then
            pid = posix.fork()
            if pid == 0 then
                ok, r = worker(label, ip, port, opt)
                -- write fdata        
                fdata = io.open(worker_data, 'w+')
                fdata:write(tostring(ok) .. '\0' .. tostring(r))
                fdata:close()
                os.exit()
            end
            fpid = io.open(worker_pid, 'w+')
            fpid:write(tostring(pid))
            fpid:close()
            os.exit()
        end

        -- read fdata
        local i = sleep / 10
        local j = 1000 * opt.timeout / i
        while j > 0 do
            msleep(i)
            fdata = io.open(worker_data, 'r')
            if fdata and fdata:read('a') then
                fdata:close()
                break
            end
            j = j - 1
        end
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
            fpid = io.open(worker_pid, 'r')
            pid = fpid:read('a')
            fpid:close()
            pcall(posix.kill, pid, 9)
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
                    utils.log.warning('servercheck: ' .. label .. ': soft-failed: ' .. v .. ' ' .. err .. '/' .. opt.softFail ..': ' .. r)
                else
                    v = 0
                    s = opt.failMultiplier * sleep
                    utils.log.error('servercheck: ' .. label .. ': hard-failed' .. ': ' .. r)
                end
            end 
        end
        if v ~= v_old then
            utils.log.info('servercheck: ' .. label .. ': ' .. v_old .. ' -> ' .. v)
            if ipc('server ' .. target .. ' ' .. v) == 'ok' then
                v_old = v
            end
            checks_total = 0
            checks_usec = 0
        end
 
        msleep(s)
    end
end

