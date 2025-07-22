local List = require "map:core/list"

-- ChunkLoader.lua
-- Класс загрузки чанков для миникарты с виртуальной картой на основе ByteArray
local ChunkLoader = {}
ChunkLoader.__index = ChunkLoader

local MAX_HEIGHT = 256  -- максимальная высота мира

function ChunkLoader:new(chunkSize, maxPerTick)
    local instance = setmetatable({}, self)
    instance.chunkSize = chunkSize or 16
    instance.maxPerTick = maxPerTick or 4
    instance.chunks = {}     -- ["cx:cy"] = { idMap = ByteArray, heightMap = ByteArray }
    instance.pending = {}
    return instance
end

-- Хэш ключа чанка
local function chunk_key(cx, cy)
    return cx .. ":" .. cy
end

-- Добавить чанк в очередь на загрузку
function ChunkLoader:enqueue_chunk(cx, cy)
    if self.chunks[chunk_key(cx, cy)] then return end
    self.pending[chunk_key(cx, cy)] = { cx = cx, cy = cy }
end

function ChunkLoader:is_scheduled(cx, cy)
    return self.pending[chunk_key(cx, cy)] ~= nil
end

-- Возвращает карты чанка (или nil)
function ChunkLoader:get_chunk(cx, cy)
    return self.chunks[chunk_key(cx, cy)]
end

-- Вызов на каждый тик
function ChunkLoader:tick()
    local processed = 0
    
    for key, chunk in pairs(self.pending) do
        if processed >= self.maxPerTick then break end
        
        if self:load_chunk(chunk.cx, chunk.cy) then
            self.pending[key] = nil  -- удаляем из очереди после успешной загрузки
            processed = processed + 1
        end
    end
end

-- Загрузить один чанк
function ChunkLoader:load_chunk(cx, cy)
    if self.chunks[chunk_key(cx, cy)] then return true end  -- уже загружен
    
    local size = self.chunkSize

    local idMap = {}
    local heightMap = {}

    local base_x = cx * size
    local base_y = cy * size

    for dx = 0, size - 1 do
        for dy = 0, size - 1 do
            local wx = base_x + dx
            local wy = base_y + dy

            local heightest_block = self:get_highest_block(wx, wy)
            if not heightest_block then return false end  -- нет блоков в этом чанке
            local id, height = unpack(heightest_block)

            table.insert(idMap, id or 0)
            table.insert(heightMap, height or 0)
        end
    end


    self.chunks[chunk_key(cx, cy)] = {
        id = idMap,
        height = heightMap
    }

    return true
end

function ChunkLoader:get_highest_block(x, z)
    if block.get(x, 128, z) == -1 then return nil end
    for y = MAX_HEIGHT - 1, 0, -1 do
        local id = block.get(x, y, z)
        if id >= 1 then return { id, y } end
    end
    return { 0, 0 }
end

return ChunkLoader
