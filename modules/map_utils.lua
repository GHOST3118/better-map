local memo = require "map:cache"
local image = require "map:image"

local MAX_HEIGHT = 256
-- Цветовая карта
local BLOCKS_COLOR_MAP = {
    
}

-- Преобразования цветов
local function rgb_to_hsl(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, l = 0, 0, (max + min) / 2

    if max ~= min then
        local delta = max - min
        if max == r then
            h = (g - b) / delta % 6
        elseif max == g then
            h = (b - r) / delta + 2
        else
            h = (r - g) / delta + 4
        end
        h = h * 60
        if h < 0 then h = h + 360 end
        s = delta / (1 - math.abs(2 * l - 1))
    end
    return h, s * 100, l * 100
end

local function hsl_to_rgb(h, s, l)
    s, l = s / 100, l / 100
    local c = (1 - math.abs(2 * l - 1)) * s
    local x = c * (1 - math.abs((h / 60 % 2) - 1))
    local m = l - c / 2
    local r, g, b

    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end

    return math.floor((r + m) * 255), math.floor((g + m) * 255), math.floor((b + m) * 255), 255
end

-- Вычисляет средний цвет текстуры, игнорируя полностью прозрачные пиксели
-- @param texture: объект с методом get(x, y) -> {r, g, b, a}
-- @param width, height: размеры текстуры
-- @return {r, g, b, a}
function getAverageColor(texture, width, height)
    local sumR, sumG, sumB, sumA = 0, 0, 0, 0
    local count = 0

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r, g, b, a = texture:get(x, y)    -- возвращает {r,g,b,a}
            if a > 0 then
                sumR = sumR + r
                sumG = sumG + g
                sumB = sumB + b
                sumA = sumA + a
                count = count + 1
            end
        end
    end

    if count == 0 then
        -- если все пиксели прозрачны
        return { 0, 0, 0, 0 }
    end

    -- усредняем компоненты и возвращаем целые значения
    local r = math.floor(sumR / count + 0.5)
    local g = math.floor(sumG / count + 0.5)
    local b = math.floor(sumB / count + 0.5)
    local a = math.floor(sumA / count + 0.5)

    return { r, g, b, a }
end

local function fetch_color_map( texture_name )
    local img = image.from_png( texture_name )

    local color = getAverageColor(img, img.width, img.height)

    local h, s, l = rgb_to_hsl(color[1], color[2], color[3])
    h = h
    s = s
    l = 50

    return { hsl_to_rgb(h, s, l) }
end

-- Получение цвета блока
local function get_block_color(block_id, y)
    local material = block.name(block_id)

    if not BLOCKS_COLOR_MAP[material] then
        local tex_name = block.get_textures(block_id)[4]
        local pack = material:match("^(.-):")
        local tex_path = pack..":textures/blocks/"..tex_name..".png"
        if file.exists(tex_path) then
            BLOCKS_COLOR_MAP[material] = fetch_color_map(tex_path)
            print("[ "..tex_path.." ] Loaded")
        end
    end

    local color = BLOCKS_COLOR_MAP[material] or { 0, 0, 0, 255 }
    local h, s, l = rgb_to_hsl(unpack(color))

    -- Уменьшение яркости с высотой
    local height_factor = (y / MAX_HEIGHT) * 50
    l = math.max(0, math.min(100, l - height_factor + math.random(-1, 0)))

    return { hsl_to_rgb(h, s, l) }
end


-- Получение высоты блока
local function get_highest_block(x, z)
    for y = MAX_HEIGHT - 1, 0, -1 do
        local id = block.get(x, y, z)
        if id >= 1 then return { id, y } end
    end
    return { 0, 0 }
end

return {
    get_block_color = get_block_color,
    get_highest_block = memo(get_highest_block, 30),
    BLOCKS_COLOR_MAP = BLOCKS_COLOR_MAP
}
