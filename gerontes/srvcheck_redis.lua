local function worker(label, ip, port, opt)
    return pcall(function()
        local redis = require('redis')
        redis = redis.connect(ip, port)
        if opt.redisAuth then
            redis.auth(opt.redisAuth)
        end
        local info = redis:info('server').server
        redis = nil
        return 1000 * (math.floor(info.server_time_usec/1000000) - info.uptime_in_seconds)
    end)
end

return {
    ['worker'] = worker,
    ['type'] = 'fork'
}
