local get_block_color = require "map:map_utils".get_block_color
local get_highest_block = require "map:map_utils".get_highest_block
local ImageBuffer = require "map:image_buffer"
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------

local MINIMAP_WIDTH = 0
local MINIMAP_HEIGHT = 0
local PIXEL_SIZE = 3
local CHUNK_SIZE = 16
local LOAD_RADIUS = 2 -- радиус чанков для загрузки вокруг игрока

local get_chunk = function(px, py)
    local chunk = ImageBuffer.new(CHUNK_SIZE * PIXEL_SIZE, CHUNK_SIZE * PIXEL_SIZE)
    for x = 0, 15, 1 do
        for y = 0, 15, 1 do
            local block_id, h = unpack(get_highest_block(math.floor(px + x - 8), math.floor(py + y - 8)))
            local color = get_block_color(block_id, h)


            chunk:drawRect((PIXEL_SIZE * x), (PIXEL_SIZE * y), PIXEL_SIZE, PIXEL_SIZE, color)
        end
    end

    return chunk
end

local function draw_chunk(buffer, cx, cy, px, py)
    local chunk = get_chunk(px, py)

    buffer:drawBuffer(chunk, cx, cy)
end

-- R — радиус в чанках (0 — только текущий, 1 — вокруг, 2 — ещё дальше и т.д.)
-- draw_chunk(buf, px, pz) — функция, рисующая один чанк
-- px,pz — мировые координаты центра (в блоках)
local function drawChunks(buff, centerX, centerY, player_x, player_y, R)
    for dx = 0, (R * 2) do
        for dy = 0, (R * 2) do
            draw_chunk(buff,
                centerX + (CHUNK_SIZE * PIXEL_SIZE * (dx - R)),
                centerY + (CHUNK_SIZE * PIXEL_SIZE * (dy - R)),
                player_x + (16 * (dx - R)),
                player_y + (16 * (dy - R))
            )
        end
    end
end

-- Обновление миникарты
local function update_minimap(canvas, player_x, player_z, player_rot)
    local buff = ImageBuffer.new(MINIMAP_WIDTH, MINIMAP_HEIGHT)

    local offsetX = MINIMAP_WIDTH / 2
    local offsetY = MINIMAP_HEIGHT / 2

    local positionX = offsetX - CHUNK_SIZE * PIXEL_SIZE / 2
    local positionY = offsetY - CHUNK_SIZE * PIXEL_SIZE / 2

    drawChunks(buff, positionX, positionY, player_x or 0, player_z or 0, LOAD_RADIUS)

    buff:rotate(player_rot)
    buff:maskCircleWithBorder(offsetX, offsetY, 100, 3, { 20, 20, 20, 220 })
    buff:drawCircle(offsetX, offsetY, 2, { 255, 255, 255, 220 })


    local data = buff:getData()

    canvas:set_data(data)
    canvas:update()
end



-- Обработчик открытия
function on_open()
    local player_id = hud.get_player()
    local canvas = document.minimap_canvas.data

    input.add_callback("key:up", function()
        PIXEL_SIZE = math.min(4, PIXEL_SIZE + 1)
        LOAD_RADIUS = math.max(1, LOAD_RADIUS - 1)
    end)

    input.add_callback("key:down", function()
        PIXEL_SIZE = math.max(1, PIXEL_SIZE - 1)
        if PIXEL_SIZE == 1 then
            LOAD_RADIUS = 6
        else
            LOAD_RADIUS = math.min(3, LOAD_RADIUS + 1)
        end
        
    end)

    

    events.on("minimap:update", function()
        MINIMAP_WIDTH, MINIMAP_HEIGHT = document.minimap_canvas.size[1], document.minimap_canvas.size[2]
        local x, y, z = player.get_pos(player_id)
        document.pcoords.text = string.format("x:%.2f y:%.2f z:%.2f", x, y, z)
        local yaw = player.get_rot(player_id, false)
        update_minimap(canvas, x, z, yaw)
    end)
end
