-- Orbit's one read of PipeWire's graph (MemberLatency, AudioGraph), run as
-- `wpexec graph/orbit_graph.lua`: wpexec comes with WirePlumber, so it works
-- on a default install, where pw-dump (pipewire-utils) is missing. It prints
-- the part of pw-dump's JSON that AudioGraph.parseDump reads, in the same
-- shape: for each Audio/Sink, its node.name, its Latency params and LDAC's
-- quality from its Props. Read only: it binds nothing new, sets nothing and
-- takes no argument, so no user data reaches it (value 11), and it ends by
-- itself. Written against WirePlumber's public Lua API (ObjectManager,
-- Interest, Constraint, Json, Core), as its documentation and the scripts
-- it ships show it; thank you to the WirePlumber developers.
local om = ObjectManager {
  Interest { type = "node",
    Constraint { "media.class", "equals", "Audio/Sink", type = "pw-global" } },
}
local out, pending = {}, 0
local function finish()
  print(Json.Array(out):to_string())
  Core.quit()
end
om:connect("installed", function(om)
  for node in om:iterate() do
    -- Props are cached by the proxy; LDAC keeps its quality there
    local props = {}
    for pod in node:iterate_params("Props") do
      local p = pod:parse().properties
      if math.type(p.quality) == "integer" then
        table.insert(props, Json.Object { quality = p.quality })
      end
    end
    -- Latency is not cached: it is asked for, and the answer comes later
    pending = pending + 1
    node:enum_params("Latency", function(it, err)
      local latency = {}
      if not err then
        for pod in it:iterate() do
          local p = pod:parse().properties
          table.insert(latency, Json.Object { direction = p.direction, minNs = p.minNs, maxNs = p.maxNs })
        end
      end
      table.insert(out, Json.Object { info = Json.Object {
        props = Json.Object { ["media.class"] = "Audio/Sink", ["node.name"] = node.properties["node.name"] },
        params = Json.Object { Latency = Json.Array(latency), Props = Json.Array(props) } } })
      pending = pending - 1
      if pending == 0 then finish() end
    end)
  end
  if pending == 0 then finish() end
end)
-- A graph that never answers ends the read anyway: nothing runs on for more than 3 s
Core.timeout_add(3000, function() Core.quit(); return false end)
om:activate()
