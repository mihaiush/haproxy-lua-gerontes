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
    local cmd = l[1]
    if cmd == 'ping' then
        r = 'ok'
    elseif cmd == 'server' then
        S[l[2]] = tonumber(l[3])
        update_servers('ipc/' .. l[2])
        r = 'ok'
    elseif cmd == 'metrics' then
        M['loop_latency'][l[2]] = l[3]
        M['server_latency'][l[2]] = l[4]
        r = 'ok'
    else
        r = 'err'
    end
    applet:send(r .. '\n')
end
core.register_service('gerontes_ipc', 'tcp', service_ipc)

-- update servers status
-- it should be called for every server or xcheck status change
xcheck = 0 -- global xcheck status
function update_servers(src)
    local mn    -- master name
    local mv    -- master value
    local sv
   
    if OPT.xCheck then
        xcheck = core.backends[OPT.xCheck]:get_srv_act()
    end
    utils.log.debug('update_servers: ' .. src .. ': xcheck: ' .. tostring(xcheck))

    for bn,bd in pairs(B) do
        mv = 0
        mn = ''
        for _,sn in ipairs(bd.servers) do
            sv = S[sn]
            if bd.xcheck and xcheck == 0 then
                sv = 0
            end
            if sv > 0 and (mv == 0 or sv < mv) then
                mn = sn
                mv = sv
            end
        end
        bd.value = mv
        -- first DOWN then UP, no 2 servers can be up
        for sn,sd in pairs(core.backends[bn].servers) do
            if sn ~= mn then
                sd:set_maint()
                sd:shut_sess()
                utils.log.info('update_servers: ' .. src .. ': ' .. bn .. '/' .. sn .. ' DOWN')
            end
        end
        for sn,sd in pairs(core.backends[bn].servers) do
            if sn == mn then
                sd:set_ready()
                utils.log.info('update_servers: ' .. src .. ': ' .. bn .. '/' .. sn .. ' UP')
            end
        end
    end
end


B = {} -- backends
S = {} -- servers
M = { ['loop_latency'] = {}, ['server_latency'] = {} } -- metrics
core.register_init(
    function()
        local bo -- backend options
        for bn,bd in pairs(core.backends) do -- backend name, backend data
            _,_,_,bo = bn:find('(.+)__gerontes_?(.*)')
            if bo then
                B[bn] = {}
                B[bn].value = 0
                bo = utils.parse_args({xcheck=false}, bo, ':', '_')
                utils.log.debug('backend: ' .. bn .. ': opt:\n' .. utils.dump(bo))
                B[bn]['xcheck'] = bo.xcheck
                if bo.xcheck then
                    if OPT.xCheck then
                        utils.log.info('backend: ' .. bn .. ': has xcheck')
                    else
                        utils.log.warning('backend: ' .. bn .. ': has xcheck but OPT.xCheck is not defined, drop xcheck')
                        B[bn]['xcheck'] = false
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
        if OPT.xCheck then
            if not core.backends[OPT.xCheck] then
                utils.log.error('backend `' .. OPT.xCheck .. '` not found, verify haproxy config', true)
            end
            for sn,sd in pairs(core.backends[OPT.xCheck].servers) do
                sd:event_sub(
                    {"SERVER_UP", "SERVER_DOWN"}, 
                    function()
                        update_servers('xcheck/' .. sn)
                    end
                )
            end
        end

        -- run check controllers    
        for target,_ in pairs(S) do
            local tp = utils.split(target,'::',1)
            if tp[2] and tp[1] ~= OPT.type then
                tp = tp[1]
            else
                tp = OPT.type
            end
            local srvcheck = require('gerontes.srvcheck_' .. tp)
            srvcheck(target)
        end
    end
)

-- options
OPT = {}
OPT.type           = '_'   -- server type
OPT.sleep          = 0.3   -- seconds between 2 checks
OPT.timeout        = 1     -- check timeout seconds
OPT.softFail       = 5     -- how many times a server check can fail before marking it down
OPT.failMultiplier = 15    -- multiplier of sleep in case the server/network were marked down
OPT.ipcSock        = '/dev/shm/gerontes.sock'   -- socket used for communication with background processes
OPT.debug          = false
OPT.xCheck         = nil -- what backend to use for extra check
OPT.mysqlUser      = nil
OPT.mysqlPassword  = nil
OPT.redisAuth      = nil
OPT.haproxyMetrics = false -- haproxy metrics url 
OPT.latencyMetrics = false -- after how many checks to report latency metrics
OPT.staticMetrics  = false -- file with static metrics calculated at startup
OPT = utils.parse_args(OPT, {...})
if OPT.debug then
    utils.log.enable_debug()
end
if OPT.logColors then
    utils.log.enable_colors()
end
-- mask passwords
mopt = {}
for ok, ov in pairs(OPT) do
    if ok:lower():find('passw') or ok:lower():find('auth') then
        mopt[ok] = 'MASKED'
    else
        mopt[ok] = ov
    end
end
utils.log.info('opt:\n' .. utils.dump(mopt))

STATIC_METRICS = ''
if OPT.staticMetrics then
    for l in io.lines(OPT.staticMetrics) do
        STATIC_METRICS = STATIC_METRICS .. 'gerontes_' .. l .. '\n'
    end  
end
