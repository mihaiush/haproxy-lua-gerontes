local function worker(label, data)
    return pcall(function()
        local v = 0
        local status = data.object.status
        if not status.containerStatuses then
            return v
        end
        local ready = true
        local started = true
        for _,c in pairs(status.containerStatuses) do
            if not c.ready then
                ready = false
            end
            if not c.started then
                started = false
            end
        end
        if ready and started then
            for _,c in pairs(status.conditions) do
                if c.type:lower() == 'ready' then
                    if c.status:lower() == 'true' then
                        v = c.lastTransitionTime
                    end
                    break
                end             
            end
        end
        if v ~= 0 then
            local p = '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z' -- 2026-03-04T15:37:18Z
            local y,m,d,H,M,S = v:match(p)
            v = 1000 * os.time{year=y, month=m, day=d, hour=H, min=M, sec=S}
        end 
        return v
    end, label, data
    )
end

local ctrl = require('gerontes.checkctrl_watch')

return function(target)
    ctrl('pod', target, worker, '/pods?fieldSelector=metadata.name=' .. utils.strip_type(target))
end
