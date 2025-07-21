-- Возвращает «декоратор», оборачивающий функцию fn в кэш с TTL (секунды)
-- fn может принимать аргументы (печатаются в ключ)
-- Возвращает новую функцию, у которой поведение как у fn, но с кэшированием
-- TODO: Сделать нормальную реализацию кэша
local function memoizeWithTTL(fn, health)
    assert(type(fn) == "function", "fn must be a function")
    assert(type(health) == "number" and health > 0, "lifetime must be positive number")

    local cache = {} -- ключ -> { value = ..., ts = timestamp }
    local now = os.time()

    local function makeKey(...)
        -- простая сериализация аргументов; TODO: заменить на более надёжную
        local t = {}
        for i = 1, select('#', ...) do
            local v = select(i, ...)
            t[#t + 1] = tostring(v)
        end
        return table.concat(t, "|")
    end

    local function regen(key, args)
        local entry = nil
        local ok, result = pcall(fn, unpack(args))
        if not ok then
            error("memoized function error: " .. tostring(result))
        end
        entry = { value = result, ts = os.time() }
        cache[key] = entry
        return entry
    end

    return function(...)
        if (os.time() - now) > health then
            cache = {} -- сброс кэша
            now = os.time() -- обновляем текущее время
            print("Cache cleared due to TTL expiration")
        end

        local key = makeKey(...)
        local entry = cache[key]

        if not entry then
            entry = regen(key, {...})
        end

        return entry.value
    end
end

return memoizeWithTTL
