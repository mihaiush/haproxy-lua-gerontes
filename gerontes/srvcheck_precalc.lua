local function worker(label, target)
    return pcall(function()
        target = utils.split(target,':')
        local url = 'http://' .. target[1] .. ':' .. target[2] .. '/gerontes?t=p&k=' .. target[3]
        local t = 1000 * OPT.timeout
        local httpclient = core.httpclient()
        local r = httpclient:get{url=url, timeout=t}
        if r.status == 200 then
            return tonumber(r.body)
        end
        error(r.status .. '/' .. r.reason)
    end)
end

return {
    ['worker'] = worker,
    ['type'] = 'task'
}
