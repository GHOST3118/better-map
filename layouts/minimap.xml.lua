local get_block_color = require "map:map_utils".get_block_color
local ImageBuffer = require "map:image_buffer"
local ChunkLoader = require "map:core/chunk/loader"

local chunkLoader
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------

local MINIMAP_WIDTH = 0
local MINIMAP_HEIGHT = 0
local PIXEL_SIZE = 3
local CHUNK_SIZE = 16
local LOAD_RADIUS = 2 -- радиус чанков для загрузки вокруг игрока

local get_chunk = function(px, py)
    local buffer = ImageBuffer.new(CHUNK_SIZE * PIXEL_SIZE, CHUNK_SIZE * PIXEL_SIZE)
    local chunk = chunkLoader:get_chunk(math.floor((px) / CHUNK_SIZE), math.floor((py) / CHUNK_SIZE))
    if not chunk then
        if not chunkLoader:is_scheduled(math.floor((px) / CHUNK_SIZE), math.floor((py) / CHUNK_SIZE)) then
            chunkLoader:enqueue_chunk(math.floor((px) / CHUNK_SIZE), math.floor((py) / CHUNK_SIZE))
        end
        buffer:clear({ 0, 0, 0, 0 }) -- полностью прозрачный
        return buffer
    end
    for x = 0, CHUNK_SIZE - 1, 1 do
        for y = 0, CHUNK_SIZE - 1, 1 do
            local block_id = chunk.id[(y * CHUNK_SIZE + x) + 1] -- ByteArray is 1-based
            local h = chunk.height[(y * CHUNK_SIZE + x) + 1] or 0
            local color = get_block_color(block_id, h)


            buffer:drawRect((PIXEL_SIZE * x), (PIXEL_SIZE * y), PIXEL_SIZE, PIXEL_SIZE, color)
        end
    end

    buffer:rotate(270)
    buffer:flip(false, true) -- отразить по горизонтали

    return buffer
end

local CACHED_CHUNKS = {}

local function draw_chunk(buffer, cx, cy, px, py)
    local chunk
    if CACHED_CHUNKS[cx..cy] then
        chunk = CACHED_CHUNKS[cx..cy]
    else
        chunk = get_chunk(px, py)
    end


    buffer:drawBuffer(chunk, cx, cy)
end

-- R — радиус в чанках (0 — только текущий, 1 — вокруг, 2 — ещё дальше и т.д.)
-- draw_chunk(buf, px, pz) — функция, рисующая один чанк
-- px,pz — мировые координаты центра (в блоках)
local function drawChunks(centerX, centerY, player_x, player_y, R)
    local buff = ImageBuffer.new(MINIMAP_WIDTH, MINIMAP_HEIGHT)

    for dx = 0, (R * 2) do
        for dy = 0, (R * 2) do
            local chunk_pixel_size = CHUNK_SIZE * PIXEL_SIZE
            local drawX = math.floor(centerX + chunk_pixel_size * (dx - R) - ((player_x * PIXEL_SIZE) % chunk_pixel_size)) + 24
            local drawY = math.floor(centerY + chunk_pixel_size * (dy - R) - ((player_y * PIXEL_SIZE) % chunk_pixel_size)) + 24


            draw_chunk(buff,
                drawX,
                drawY,
                player_x + (CHUNK_SIZE * (dx - R)),
                player_y + (CHUNK_SIZE * (dy - R))
            )
        end
    end

    return buff
end

-- Обновление миникарты
local function update_minimap(canvas, player_x, player_z, player_rot)
    local buff = ImageBuffer.new(MINIMAP_WIDTH, MINIMAP_HEIGHT)

    local offsetX = MINIMAP_WIDTH / 2
    local offsetY = MINIMAP_HEIGHT / 2

    local positionX = offsetX - CHUNK_SIZE * PIXEL_SIZE / 2
    local positionY = offsetY - CHUNK_SIZE * PIXEL_SIZE / 2

    local chunks = drawChunks(positionX, positionY, player_x or 0, player_z or 0, LOAD_RADIUS)

    buff:drawBuffer(chunks, 0, 0)
    chunks = nil -- освобождаем память
    buff:rotate(player_rot)
    buff:maskCircleWithBorder(offsetX, offsetY, 100, 3, { 20, 20, 20, 220 })
    buff:drawCircle(offsetX, offsetY, 2, { 255, 255, 255, 220 })


    local data = buff:getData()

    canvas:set_data(data)
    canvas:update()
end



-- Обработчик открытия
function on_open()
    chunkLoader = ChunkLoader:new(CHUNK_SIZE, 1)
    CACHED_CHUNKS = {}

    local player_id = hud.get_player()
    local canvas = document.minimap_canvas.data

    input.add_callback("key:up", function()
        PIXEL_SIZE = math.min(4, PIXEL_SIZE + 1)
        LOAD_RADIUS = math.max(2, LOAD_RADIUS - 1)
    end)

    input.add_callback("key:down", function()
        PIXEL_SIZE = math.max(1, PIXEL_SIZE - 1)
        if PIXEL_SIZE == 1 then
            LOAD_RADIUS = 7
        else
            LOAD_RADIUS = math.min(3, LOAD_RADIUS + 1)
        end
    end)



    events.reset("minimap:update", function()
        MINIMAP_WIDTH, MINIMAP_HEIGHT = document.minimap_canvas.size[1], document.minimap_canvas.size[2]
        local x, y, z = player.get_pos(player_id)
        document.pcoords.text = string.format("x:%.2f y:%.2f z:%.2f", x, y, z)



        local yaw = player.get_rot(player_id, false)
        update_minimap(canvas, x, z, yaw)

        chunkLoader:tick()
    end)
end
