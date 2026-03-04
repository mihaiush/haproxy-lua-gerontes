local function worker(label, target)
    target = utils.split(target,':')
    local url = 'http://' .. target[1] .. ':' .. target[2] .. '/gerontes?t=p&k=' .. target[3]
    local httpclient = core.httpclient()
    local r = httpclient:get{url=url, timeout=1000*OPT.timeout}
    httpclient = nil
    if r.status == 200 then
        return true, tonumber(r.body)
    end
    return false, r.status .. '/' .. r.reason
end

local ctrl = require('gerontes.checkctrl_task')

return function(target)
    ctrl('precalc', target, worker)
end

