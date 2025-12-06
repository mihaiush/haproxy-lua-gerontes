return function(label, ip, port, opt)
    local redis = require('redis')
    ok, r = pcall(function()
        redis = redis.connect(ip, port)
        local info = redis:info('server').server
        return 1000 * (math.floor(info.server_time_usec/1000000) - info.uptime_in_seconds)
    end)
    if not ok then
        utils.log.error('servercheck: ' .. label .. ': ' .. r)
        r = 0
    end
    return r
end
