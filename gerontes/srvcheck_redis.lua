return function(label, ip, port, opt)
    return pcall(function()
        local redis = require('redis')
        redis = redis.connect(ip, port)
        local info = redis:info('server').server
        redis = nil
        return 1000 * (math.floor(info.server_time_usec/1000000) - info.uptime_in_seconds)
    end)
end
