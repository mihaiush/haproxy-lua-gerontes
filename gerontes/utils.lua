
utils={}

utils.split = require('string.split')

utils.log = {}
local colors = require('ansicolors')
local _colors = false
function utils.log.enable_colors()
    _colors = true
end
local _debug = false
function utils.log.enable_debug()
    _debug = true
end
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
    msg = '[gerontes][' .. lvl .. '] ' .. os.date('%Y-%m-%d %H:%M:%S') .. ' ' .. msg
    if _colors then
        msg = colors('%{' .. clr .. '}' .. msg .. '%{reset}')
    end
    io.stderr:write(msg .. '\n')
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
        _colors,
        function(x) out = out .. x end
    )
    return string.gsub(out, '\n$', '')
end

utils.parse_args = function(def, args, s1, s2, m)
    -- key/value separator
    if not s1 then
        s1 = '='
    end
    -- args separator
    if not s2 then
        s2 = ' '
    end
    -- mandatory marker
    if not m then
        m = '_'
    end
    if type(args) == 'string' then
        args = utils.split(args, s2)
    end
    local opt = {}
    for k, v in pairs(def) do
        opt[k] = v
    end
    for _,a in ipairs(args) do
        a = utils.split(a, s1, 1)
        if a[1] ~= '' then
            opt[a[1]] = tonumber(a[2]) or a[2]
            if a[2] == 'yes' or a[2] == 'true' or not a[2] then
                opt[a[1]] = true
            elseif a[2] == 'no' or a[2] == 'false' then 
                opt[a[1]] = false
            end
        end
    end 
    for o,v in pairs(opt) do
        if v == m then
            utils.log.error('parse-args:' .. o ..  ' is undefined', true)
        end
    end
    return opt
end

return utils
