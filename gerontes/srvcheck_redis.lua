local function worker(label, target)
    local ip = utils.split(target,':')[1]
    local port = utils.split(target,':')[2]
    return pcall(function()
        local redis = require('redis')
        redis = redis.connect(ip, port)
        if OPT.redisAuth then
            redis.auth(OPT.redisAuth)
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
