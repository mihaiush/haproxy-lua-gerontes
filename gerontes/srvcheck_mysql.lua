return function(label, ip, port, opt)
    return pcall(function()
        local driver = require('luasql.mysql')
        local env = driver.mysql()
        local conn = assert(env:connect('information_schema', opt.mysqlUser, opt.mysqlPassword, ip, port), "Connection refused")
        local cur = conn:execute("select (unix_timestamp() - VARIABLE_VALUE) from global_status where VARIABLE_NAME='UPTIME'")
        r = cur:fetch({})
        r = 1000 * r[1]
        cur:close()
        conn:close()
        env:close()

        return r
    end)
end
