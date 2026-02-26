local function worker (label, target, opt)
    local ip = utils.split(target,':')[1]
    local port = utils.split(target,':')[2]
    return pcall(function()
        local driver = require('luasql.mysql')
        local env = driver.mysql()
        local conn = assert(env:connect('information_schema', opt.mysqlUser, opt.mysqlPassword, ip, port), "Connection refused")
        local cur = conn:execute("select (unix_timestamp() - VARIABLE_VALUE) from global_status where VARIABLE_NAME='UPTIME'")
        local r = cur:fetch({})
        cur:close()
        conn:close()
        env:close()
 
        return 1000 * r[1]
    end)
end

return { 
    ['worker'] = worker,
    ['type'] = 'fork'
}
