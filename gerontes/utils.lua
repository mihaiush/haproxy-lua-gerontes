
utils={}

utils.split = require('string.split')
utils.toip = require('socket').dns.toip

utils.log = {}
local colors = require('ansicolors')
local function _log(lvl, msg)
    local l = string.sub(lvl, 1, 1)
    if l == 'i' then
        clr = 'bright white'
    elseif l == 'd' then
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
function utils.log.error(msg, ext)
    local i = debug.getinfo(2, 'S')
    _log('error  ', msg)
    if ext then
        error(i.source)
    end
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
    return string.gsub(out, '\n$', '')
end

utils.parse_args = function(def, args)
    opt = {}
    for k, v in pairs(def) do
        opt[k] = v
    end
    for _,a in ipairs(args) do
        a = utils.split(a,'=')
        opt[a[1]] = tonumber(a[2]) or a[2]
        opt[a[1]] = a[2] or true
    end 
    if opt.debug then
        utils.log.enable_debug()
    end
    for o,v in pairs(opt) do
        if v == '_' then
            utils.log.error('parse-args:' .. o ..  ' is undefined', true)
        end
    end
    utils.log.debug('parse-args: dump:\n' .. utils.dump(opt))
    return opt
end

return utils
