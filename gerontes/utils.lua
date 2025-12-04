
utils={}

utils.sleep = require('time.sleep')

utils.log = {}
local colors = require('ansicolors')
local function _log(lvl, msg)
    local l = string.sub(lvl, 1, 1)
    if l == 'd' then
        clr = 'cyan'
    elseif l == 'e' then
        clr = 'red'
    elseif l == 'w' then
        clr = 'yellow'
    else
        clr = 'reset'
    end
    print(colors('%{' .. clr .. '}[gerontes][' .. lvl .. '] ' .. os.date('%Y-%m-%d %H:%M:%S') .. ' ' .. msg .. '%{reset}'))
end
local _debug = false
function utils.log.enable_debug()
    _debug = true
end
function utils.log.info(msg)
    _log('info   ', msg)
end
function utils.log.debug(msg)
    if _debug then
        _log('debug  ', msg)
    end
end
function utils.log.error(msg)
    local i = debug.getinfo(2, 'S')
    _log('error  ', msg)
    error(i.source)
end
function utils.log.warning(msg)
    _log('warning', msg)
end

require('print_r')
utils.dump = function(data)
    local out = ''
    print_r(
        data,
        true,
        function(x) out = out .. x end
    )
    return out
end

return utils
