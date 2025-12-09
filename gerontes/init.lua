posix = require('posix')
utils = require('gerontes.utils')

-- metrics
local service_metrics = require('gerontes.metrics')
core.register_service('gerontes_metrics', 'http', service_metrics)


-- receive events from forks
local function service_ipc(applet)
    local r
    local l = applet:getline()
    l = string.gsub(l, '\n$', '')
    utils.log.debug('ipc: recive: ' .. l)
    l = utils.split(l,' ')
    cmd = l[1]
    if cmd == 'ping' then
        r = 'ok'
        utils.log.info('ipc: check ok')
    elseif cmd == 'server' then
        S[l[2]] = tonumber(l[3])
        S_latency[l[2]] = tonumber(l[4])
        update_servers('ipc/' .. l[2])
        r = 'ok'
    else 
        r = 'err'
    end
    applet:send(r .. '\n')
end
core.register_service('gerontes_ipc', 'tcp', service_ipc)


-- update servers status
-- it should be called for every server or xcheck status change
function update_servers(src)
    local xc    -- xcheck value 
    local mn    -- master name
    local mv    -- master value
    local sv
    local cflag -- check flag
   
    utils.log.debug('update_servers: src: ' .. src)

    xc = true
    if opt.xCheck then
        xc = core.backends[opt.xCheck]:get_srv_act()
        if xc == 0 then
            xc = false
        else
            xc = true
        end
    end
    utils.log.debug('update_servers: xcheck: ' .. tostring(xc))

    for bn,bd in pairs(B) do
        cflag = true
        if bd.xcheck and not xc then
            cflag = false
        end
        mv = 0
        mn = ''
        for _,sn in ipairs(bd.servers) do
            sv = S[sn]
            if cflag and sv > 0 and (mv == 0 or sv < mv) then
                mn = sn
                mv = sv
            end
        end
        for sn,sd in pairs(core.backends[bn].servers) do
            if sn == mn then
                sd:check_force_up()
                utils.log.debug('update_servers: ' .. bn .. '/' .. sn .. ' UP')            
            else
                sd:check_force_down()
                utils.log.debug('update_servers: ' .. bn .. '/' .. sn .. ' DOWN')
            end
        end
    end
end


B = {} -- backends
S = {} -- servers
S_latency = {} 
core.register_init(
    function()
        local bo -- backend options
        for bn,bd in pairs(core.backends) do -- backend name, backend data
            _,_,_,bo = bn:find('(.+)__gerontes_?(.*)')
            if bo then
                B[bn] = {}
                bo = utils.parse_args({xcheck=false}, bo, ':', '_')
                utils.log.debug('backend: ' .. bn .. ': opt:\n' .. utils.dump(bo))
                B[bn]['xcheck'] = bo.xcheck
                if bo.xcheck then
                    if opt.xCheck then
                        utils.log.info('backend: ' .. bn .. ': has xcheck')
                    else
                        utils.log.warning('backend: ' .. bn .. ': has xcheck but opt.xCheck is not defined')
                    end
                end
                B[bn]['servers'] = {}
                for sn,sd in pairs(bd.servers) do
                    utils.log.info('backend: ' .. bn .. ': server: ' .. sn)
                    table.insert(B[bn]['servers'], sn)
                    S[sn] = 0
                end
            end
        end

        utils.log.debug('backends:\n' .. utils.dump(B))
        utils.log.debug('servers:\n' .. utils.dump(S))

        -- events on xcheck servers
        if opt.xCheck then
            for sn,sd in pairs(core.backends[opt.xCheck].servers) do
                sd:event_sub(
                    {"SERVER_UP", "SERVER_DOWN"}, 
                    function()
                        update_servers('xcheck/' .. sn)
                    end
                )
            end
        end

        -- start servercheck forks
        local srvcheck = require('gerontes.srvcheck')
        for t,_ in pairs(S) do
            if posix.fork() == 0 then
                -- in case unexpected error raises in forked process we restart
                while true do
                    local ok, r = pcall(srvcheck, t, opt)
                    if not ok then
                        utils.log.error('servercheck terminated with error: ' .. r)
                    end
                end
                os.exit(1)
            end
        end
    end
)


-- options
opt = {}
opt.type           = '_'   -- server type
opt.sleep          = 0.3   -- seconds between 2 checks
opt.timeout        = 2     -- check timeout seconds
opt.softFail       = 5     -- how many times a server check can fail before marking it down
opt.failMultiplier = 15    -- multiplier of sleep in case the server/network were marked down
opt.ipcSock        = '/dev/shm/gerontes.sock'   -- socket used for communication with background processes
opt.ipcForce       = nil -- after how many checks to force ipc (normal only at status change)
opt.debug          = nil
opt.xCheck         = nil -- what backend to use for extra check
opt.mysqlUser      = nil
opt.mysqlPassword  = nil
opt.metrics        = nil -- haproxy metrics url 
opt = utils.parse_args(opt, {...})
if opt.debug then
    utils.log.enable_debug()
end
if opt.logColors then
    utils.log.enable_colors()
end
utils.log.debug('opt:\n' .. utils.dump(opt))

