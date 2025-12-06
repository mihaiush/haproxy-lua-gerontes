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

    local errors = 0
    local sleep = 1000 * opt.sleep
    local v = 0
    local s
    local v_old = -1
    local ip 
    local port
    local worker = require('gerontes.srvcheck_' .. opt.type)
    local r = 0
    while ipc('ping') ~= 'ok' do
        msleep(sleep)
    end
    while true do
        s = sleep

        -- we split target here in ip and port to solve hostname -> ip
        ip = utils.toip(utils.split(target,':')[1])
        port = utils.split(target,':')[2]
        r = worker(label, ip, port, opt)        

        if r ~= 0 then
            v = r
            errors = 0
        else
            if v_old ~= -1 then
                if errors < opt.serverSoftFail then
                    v = v_old
                    errors = errors + 1
                    utils.log.warning('servercheck: ' .. label .. ': soft-failed: ' .. v .. ' ' .. errors .. '/' .. opt.serverSoftFail)
                else
                    v = 0
                    s = opt.failMultiplier * sleep
                    utils.log.error('servercheck: ' .. label .. ': hard-failed')
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

