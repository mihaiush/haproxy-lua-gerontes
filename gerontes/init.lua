posix = require('posix')
utils = require('gerontes.utils')

-- receive events from forks
function service_ipc(applet)
    local r
    local l = applet:getline()
    l = string.gsub(l, '\n$', '')
    utils.log.debug('service_bkg_event: recive: ' .. l)
    l = utils.split(l,' ')
    cmd = l[1]
    if cmd == 'ping' then
        r = 'ok'
    elseif cmd == 'server' then
        S[l[2]] = tonumber(l[3])
        update_servers()
        r = 'ok'
    else 
        r = 'err'
    end
    applet:send(r .. '\n')
end

-- if one netcheck is up -> network up
function up_net()
    for _,n in pairs(N) do
        if n == 1 then
            return true
        end
    end
    return false
end

-- update servers status
-- it should be called every time a network/server check changes
function update_servers()
    local n   -- net status
    local mn  -- master name
    local mv  -- master value
    local sv
    for bn,bd in pairs(B) do
        n = true
        if bd.netcheck and not up_net() then
            n = false
        end
        mv = 0
        mn = ''
        for _,sn in ipairs(bd.servers) do
            sv = S[sn]
            if n and sv > 0 and (mv == 0 or sv < mv) then
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

-- options
-- _, mandatory without default
opt = {}
opt.type           = '_'  -- server type
opt.sleep          = 0.3  -- seconds between 2 checks
opt.netTimeout     = 7    -- network check timeout, multiple of sleep
opt.serverSoftFail = 7    -- how many times a server check can fail before marking it down
opt.netSoftFail    = 3    -- how many times a network check can fail before marking it down
opt.failMultiplier = 15   -- multiplier of sleep in case the server/network were marked down
opt.netCheck       = ''   -- what endpoints to check for network conectivity IP1:PORT1,IP2:PORT2,..,IPn:PORTn
opt.ipcSock        = '_' -- socket used for communication with background processes
-- opt.serverTimeout  = 17   -- server check timeout, multiple of sleep
local args = table.pack(...)
for _,a in ipairs(args) do
    a = utils.split(a,'=')
    if a[1] == 'debug' then
        opt.debug = true
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
core.register_service('gerontes_ipc', 'tcp', service_ipc)
core.register_init(
    function()
        local bo -- backend options
        for bn,bd in pairs(core.backends) do -- backend name, backend data
            _,_,_,bo = bn:find('(.+)__gerontes(.*)')
            if bo then
                B[bn] = {}
                B[bn]['servers'] = {}
                for sn,_ in pairs(bd.servers) do
                    utils.log.info('backend: ' .. bn .. ': server: ' .. sn)
                    table.insert(B[bn]['servers'], sn)
                    S[sn] = 0
                end
                B[bn]['netcheck'] = false
                n,_,_ = bo:find('_netcheck')
                if n then
                    B[bn]['netcheck'] = true
                    utils.log.info('backend: ' .. bn .. ': has netcheck')
                end
            end
        end

        -- process netcheck config
        local ip
        local port
        for _,t in ipairs(utils.split(opt.netCheck,',')) do
            ip = utils.toip(utils.split(t,':')[1])
            port = utils.split(t,':')[2]
            utils.log.info('netcheck: ' .. t .. ' -> ' .. ip .. ':' .. port)
            t = ip .. ':' .. port
            N[t] = 0
        end

        utils.log.debug('backends:\n' .. utils.dump(B))
        utils.log.debug('servers:\n' .. utils.dump(S))
        utils.log.debug('netchecks:\n' .. utils.dump(N))

        -- register net checks
        local task_netcheck = require('gerontes.netcheck')
        for t,_ in pairs(N) do
            core.register_task(task_netcheck, t)
        end

        -- start srv check threads
        local srvcheck = require('gerontes.srvcheck')
        for t,_ in pairs(S) do
            if posix.fork() == 0 then
                srvcheck(t, opt)
                error('exit fork ' .. t)
            end
        end
    end
)
