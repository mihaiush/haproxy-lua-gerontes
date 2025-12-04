utils = require('gerontes.utils')

-- options
-- _, mandatory without default
local opt = {}
opt.type           = '_'  -- server type
opt.sleep          = 0.3  -- seconds between 2 checks
opt.serverTimeout  = 17   -- server check timeout, multiple of sleep
opt.netTimeout     = 7    -- network check timeout, multiple of sleep
opt.serverSoftFail = 5    -- how many times a server check can fail before marking it down
opt.netSoftFail    = 3    -- how many times a network check can fail before marking it down
opt.failMultiplier = 15   -- multiplier of sleep in case the server/network were marked down
opt.netCheck       = ''   -- what endpoints to check for network conectivity IP1:PORT1,IP2:PORT2,..,IPn:PORTn
opt.threadSock     = '/dev/shm/gerontes.sock' -- socket used for communication between threads
local args = table.pack(...)
for _,a in ipairs(args) do
    a = core.tokenize(a,'=')
    if a[1] == 'debug' then
        utils.log.enable_debug() 
    else
        opt[a[1]] = a[2]
    end
end
for o,v in pairs(opt) do
    if v == '_' then
        utils.log.error('opt:' .. o ..  ' is undefined')
    end
end
utils.log.debug('opt:\n' .. utils.dump(opt))
