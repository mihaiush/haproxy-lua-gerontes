utils = require('gerontes.utils')
require('gerontes.netcheck')

-- receive events from background threads
function service_bkg_event(applet)
    local r
    local cmd = applet:getline()
    cmd = string.gsub(cmd, '\n$', '')
    utils.log.debug('service_bkg_event: cmd: ' .. tostring(cmd))
    if cmd == 'ping' then
        r = 'ok'
    else 
        r = 'err'
    end
    applet:send(r .. '\n')
end

-- options
-- _, mandatory without default
opt = {}
opt.type           = '_'  -- server type
opt.sleep          = 0.3  -- seconds between 2 checks
opt.serverTimeout  = 17   -- server check timeout, multiple of sleep
opt.netTimeout     = 7    -- network check timeout, multiple of sleep
opt.serverSoftFail = 5    -- how many times a server check can fail before marking it down
opt.netSoftFail    = 3    -- how many times a network check can fail before marking it down
opt.failMultiplier = 15   -- multiplier of sleep in case the server/network were marked down
opt.netCheck       = ''   -- what endpoints to check for network conectivity IP1:PORT1,IP2:PORT2,..,IPn:PORTn
opt.bkgEventSock   = '/dev/shm/gerontes.sock' -- socket used for communication with classic threads
local args = table.pack(...)
for _,a in ipairs(args) do
    a = core.tokenize(a,'=')
    if a[1] == 'debug' then
        utils.log.enable_debug() 
    else
        opt[a[1]] = a[2]
    end
end
for o,v in pairs(opt) do
    if v == '_' then
        utils.log.error('opt:' .. o ..  ' is undefined', true)
    end
end
utils.log.debug('opt:\n' .. utils.dump(opt))

B={} -- backends
S={} -- servers
N={} -- net
core.register_service('gerontes_bkg_event', 'tcp', service_bkg_event)
core.register_init(
    function()
        local bo -- backend options
        local n  -- netcheck
        for bn,bd in pairs(core.backends) do -- backend name, backend data
            _, _, _, bo = bn:find('(.+)__gerontes(.*)')
            if bo then
                utils.log.info('backend: ' .. bn .. ': found')
                B[bn] = {}
                B[bn]['netcheck'] = false
                n, _, _ = bo:find('_netcheck')
                if n then
                    B[bn]['netcheck'] = true
                    utils.log.info('backend: ' .. bn .. ': has netcheck')
                end
                B[bn]['servers'] = {}
                for sn, sd in pairs(bd.servers) do -- server name, server data
                    utils.log.info('backend: ' .. bn .. ': found server: ' .. sd:get_addr())
                    B[bn]['servers'][sd:get_addr()] = sn
                    S[sd:get_addr()] = 0
                end
            end
        end
        for _,n in ipairs(core.tokenize(opt.netCheck,',')) do
            N[n] = 0
            core.register_task(task_netcheck, n)
        end
        utils.log.debug('backends:\n' .. utils.dump(B))
        utils.log.debug('servers:\n' .. utils.dump(S))
        utils.log.debug('netchecks:\n' .. utils.dump(N))
    end
)
