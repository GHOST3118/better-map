local chunkLoader = require "map:core/chunk/loader"


function on_world_tick()
    events.emit("minimap:update")
end