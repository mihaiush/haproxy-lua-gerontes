local function worker(label, target)
    target = utils.split(target,':')
    local ip = target[1]
    local port = target[2]
 
   return pcall(function()
        local redis = require('redis')
        redis = redis.connect(ip, port)
        if OPT.redisAuth then
            redis:auth(OPT.redisAuth)
        end
        local info = redis:info('server').server
        redis = nil
        return 1000 * (math.floor(info.server_time_usec/1000000) - info.uptime_in_seconds)
    end)
end

local ctrl = require('gerontes.checkctrl_fork')

return function(target)
    ctrl('redis', target, worker)
end

