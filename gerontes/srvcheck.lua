return function(target, opt)
    local label = opt.type .. '/' .. target
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
    local ip 
    local port
    local worker = require('gerontes.srvcheck_' .. opt.type)
    local r = 0
    local ok = false
    
    msleep (2 * sleep) -- wait for ipc to start
    while ipc('ping') ~= 'ok' do
        utils.log.error('servercheck: ' .. label .. ': ipc check failed')
        msleep(sleep)
    end
    while true do
        s = sleep

        -- we split target here in ip and port to solve hostname -> ip
        ip = utils.toip(utils.split(target,':')[1])
        port = utils.split(target,':')[2]
        ok, r = worker(label, ip, port, opt)        

        if ok then
            v = r
            err = 0
        else
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
        end
        msleep(s)
    end
end

