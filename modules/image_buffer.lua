
local ImageBuffer = {}
ImageBuffer.__index = ImageBuffer

-- Конструктор: создаёт буфер width×height, заполняя прозрачным цветом
function ImageBuffer.new(width, height)
    assert(width > 0 and height > 0, "Width and height must be positive")
    local self = setmetatable({}, ImageBuffer)
    self.width  = width
    self.height = height
    -- Одномерный массив RGBA
    local total = width * height * 4
    self.data = {}
    for i = 1, total do
        self.data[i] = 0  -- по умолчанию прозрачный (r=0,g=0,b=0,a=0)
    end
    return self
end

-- Вспомогательная функция: проверка попадания в границы
function ImageBuffer:inBounds(x, y)
    return x >= 0 and x < self.width and y >= 0 and y < self.height
end

-- Заполнить весь буфер одним цветом {r,g,b,a}
function ImageBuffer:clear(color)
    local r, g, b, a = unpack(color)
    local w, h = self.width, self.height
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local idx = (y * w + x) * 4 + 1
            self.data[idx]     = r
            self.data[idx + 1] = g
            self.data[idx + 2] = b
            self.data[idx + 3] = a
        end
    end
end

--- Отзеркаливание изображения
-- @param horizontal: если true, отражает по горизонтали (вдоль вертикальной оси)
-- @param vertical: если true, отражает по вертикали (вдоль горизонтальной оси)
function ImageBuffer:flip(horizontal, vertical)
    local w, h = self.width, self.height
    local newBuf = ImageBuffer.new(w, h)

    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local srcX = horizontal and (w - 1 - x) or x
            local srcY = vertical and (h - 1 - y) or y
            local srcIdx = (srcY * w + srcX) * 4 + 1
            local color = {
                self.data[srcIdx],
                self.data[srcIdx + 1],
                self.data[srcIdx + 2],
                self.data[srcIdx + 3]
            }
            newBuf:setPixel(x, y, color)
        end
    end

    self.data = newBuf:getData()
    return self
end

-- Установить цвет одного пикселя
function ImageBuffer:setPixel(x, y, color)
    if not self:inBounds(x, y) then return end
    local r, g, b, a = unpack(color)
    local idx = (y * self.width + x) * 4 + 1
    self.data[idx]     = r
    self.data[idx + 1] = g
    self.data[idx + 2] = b
    self.data[idx + 3] = a
end

-- Нарисовать заполненный прямоугольник
function ImageBuffer:drawRect(x, y, w, h, color)
    local r, g, b, a = unpack(color)
    local maxX, maxY = self.width - 1, self.height - 1
    for dy = 0, h - 1 do
        local yy = y + dy
        if yy >= 0 and yy <= maxY then
            for dx = 0, w - 1 do
                local xx = x + dx
                if xx >= 0 and xx <= maxX then
                    local idx = (yy * self.width + xx) * 4 + 1
                    self.data[idx]     = r
                    self.data[idx + 1] = g
                    self.data[idx + 2] = b
                    self.data[idx + 3] = a
                end
            end
        end
    end
end

-- Нарисовать заполненный круг
function ImageBuffer:drawCircle(cx, cy, radius, color)
    local r2 = radius * radius
    local r, g, b, a = unpack(color)
    local maxX, maxY = self.width - 1, self.height - 1
    for dy = -radius, radius do
        local yy = cy + dy
        if yy >= 0 and yy <= maxY then
            for dx = -radius, radius do
                if dx*dx + dy*dy <= r2 then
                    local xx = cx + dx
                    if xx >= 0 and xx <= maxX then
                        local idx = (yy * self.width + xx) * 4 + 1
                        self.data[idx]     = r
                        self.data[idx + 1] = g
                        self.data[idx + 2] = b
                        self.data[idx + 3] = a
                    end
                end
            end
        end
    end
end

-- Поворот холста на угол angle (в градусах), возвращает новый ImageBuffer
function ImageBuffer:rotate(angle)
    local rad = math.rad(angle)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local w, h = self.width, self.height
    local newBuf = ImageBuffer.new(w, h)
    local cx, cy = (w - 1) * 0.5, (h - 1) * 0.5

    for y = 0, h - 1 do
        for x = 0, w - 1 do
            -- координаты относительно центра
            local rx, ry = x - cx, y - cy
            -- обратное преобразование
            local srcX =  rx * cosA + ry * sinA + cx
            local srcY = -rx * sinA + ry * cosA + cy
            local ix, iy = math.floor(srcX + 0.5), math.floor(srcY + 0.5)
            if self:inBounds(ix, iy) then
                local idxSrc = (iy * w + ix) * 4 + 1
                local color = {
                    self.data[idxSrc],
                    self.data[idxSrc + 1],
                    self.data[idxSrc + 2],
                    self.data[idxSrc + 3]
                }
                newBuf:setPixel(x, y, color)
            end
        end
    end
    self.data = newBuf:getData()
    return newBuf
end

-- Обрезать содержимое по кругу: всё вне радиуса становится прозрачным
-- cx, cy — центр круга, radius — радиус
function ImageBuffer:maskCircle(cx, cy, radius)
    local r2 = radius * radius
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local dx = x - cx
            local dy = y - cy
            if dx*dx + dy*dy > r2 then
                -- индекс альфа-компоненты
                local idx = (y * self.width + x) * 4 + 4
                self.data[idx] = 0
            end
        end
    end
    return self
end

--- Копирует один буфер в другой с заданным смещением
-- @param src: исходный ImageBuffer
-- @param dstX, dstY: позиция, куда рисовать в текущем буфере
function ImageBuffer:drawBuffer(src, dstX, dstY)
    local sw, sh = src.width, src.height
    local dw, dh = self.width, self.height
    local sdata = src.data

    for sy = 0, sh - 1 do
        local dy = dstY + sy
        if dy >= 0 and dy < dh then
            for sx = 0, sw - 1 do
                local dx = dstX + sx
                if dx >= 0 and dx < dw then
                    local sidx = (sy * sw + sx) * 4
                    local didx = (dy * dw + dx) * 4
                    self.data[didx + 1] = sdata[sidx + 1] -- R
                    self.data[didx + 2] = sdata[sidx + 2] -- G
                    self.data[didx + 3] = sdata[sidx + 3] -- B
                    self.data[didx + 4] = sdata[sidx + 4] -- A
                end
            end
        end
    end
end

--- Маскирует изображение кругом и добавляет обрамление
-- @param cx, cy: центр круга
-- @param radius: радиус круга
-- @param border_thickness: толщина обрамления в пикселях
-- @param border_color: таблица {r, g, b, a}
function ImageBuffer:maskCircleWithBorder(cx, cy, radius, border_thickness, border_color)
    local r2 = radius * radius
    local inner_r2 = (radius - border_thickness)^2

    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local dx = x - cx
            local dy = y - cy
            local dist2 = dx*dx + dy*dy
            local idx = (y * self.width + x) * 4

            if dist2 > r2 then
                -- за пределами круга: полностью прозрачный
                self.data[idx + 4] = 0
            elseif dist2 > inner_r2 then
                -- в зоне обрамления: рисуем border_color
                self.data[idx + 1] = border_color[1] or 0
                self.data[idx + 2] = border_color[2] or 0
                self.data[idx + 3] = border_color[3] or 0
                self.data[idx + 4] = border_color[4] or 255
            end
            -- внутри круга (dist2 <= inner_r2): оставляем пиксель как есть
        end
    end

    return self
end

-- Вернуть сырой массив RGBA (1D table)
function ImageBuffer:getData()
    return self.data
end

return ImageBuffer