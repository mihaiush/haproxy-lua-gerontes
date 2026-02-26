utils = require('gerontes.utils')

-- metrics
local service_metrics = require('gerontes.metrics')
core.register_service('gerontes_metrics', 'http', service_metrics)

-- update servers status
-- it should be called for every server or xcheck status change
xcheck = 0 -- global xcheck status
function update_servers(src)
    local mn    -- master name
    local mv    -- master value
    local sv
   
    if opt.xCheck then
        xcheck = core.backends[opt.xCheck]:get_srv_act()
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
                    if opt.xCheck then
                        utils.log.info('backend: ' .. bn .. ': has xcheck')
                    else
                        utils.log.warning('backend: ' .. bn .. ': has xcheck but opt.xCheck is not defined, drop xcheck')
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
        if opt.xCheck then
            if not core.backends[opt.xCheck] then
                utils.log.error('backend `' .. opt.xCheck .. '` not found, verify haproxy config', true)
            end
            for sn,sd in pairs(core.backends[opt.xCheck].servers) do
                sd:event_sub(
                    {"SERVER_UP", "SERVER_DOWN"}, 
                    function()
                        update_servers('xcheck/' .. sn)
                    end
                )
            end
        end

        -- run check controllers    
        for t,_ in pairs(S) do
            local precalc = utils.split(t,':',1)[1] == 'p'
            print_r(precalc)
            if precalc then
                local pctrl = require('gerontes.checkctrl_task')
                pctrl(t, 'precalc', opt)
            else
                checkctrl(t, opt.type, opt)
            end
        end
    end
)

-- options
opt = {}
opt.type           = '_'   -- server type
opt.sleep          = 0.3   -- seconds between 2 checks
opt.timeout        = 1     -- check timeout seconds
opt.softFail       = 5     -- how many times a server check can fail before marking it down
opt.failMultiplier = 15    -- multiplier of sleep in case the server/network were marked down
opt.ipcSock        = '/dev/shm/gerontes.sock'   -- socket used for communication with background processes
opt.debug          = false
opt.xCheck         = nil -- what backend to use for extra check
opt.mysqlUser      = nil
opt.mysqlPassword  = nil
opt.haproxyMetrics = false -- haproxy metrics url 
opt.latencyMetrics = false -- after how many checks to report latency metrics
opt.staticMetrics  = false -- file with static metrics calculated at startup
opt = utils.parse_args(opt, {...})
if opt.debug then
    utils.log.enable_debug()
end
if opt.logColors then
    utils.log.enable_colors()
end
-- mask passwords
mopt = {}
for ok, ov in pairs(opt) do
    if ok:lower():find('passw') then
        mopt[ok] = 'MASKED'
    else
        mopt[ok] = ov
    end
end
utils.log.info('opt:\n' .. utils.dump(mopt))

local ok, r = pcall(require, 'gerontes.srvcheck_' .. opt.type)
if not ok then
    utils.log.error('Error loading servercheck `' .. opt.type .. '`\n' .. r, true)
else
    checkctrl = require('gerontes.checkctrl_' .. r.type)
end


STATIC_METRICS = ''
if opt.staticMetrics then
    for l in io.lines(opt.staticMetrics) do
        STATIC_METRICS = STATIC_METRICS .. 'gerontes_' .. l .. '\n'
    end  
end
