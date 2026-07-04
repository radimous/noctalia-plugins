-- based on https://github.com/Cleboost/noctalia-plugins/blob/main/zed-projects/zed_projects.luau

prismPath = "~/.local/share/PrismLauncher" -- TODO(config)
local function getPrismPath()
    return noctalia.expandPath(prismPath)
end

local cachedInstances = nil

local function trim(s)
  return (s:match("^%s*(.-)%s*$"))
end

local function instanceName(path)
  return path:match("([^/]+)$") or path
end

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\"'\"'") .. "'"
end

local function loadInstances(onDone)
  local prism = getPrismPath()
  local instances = prism .. "/instances" -- TODO: read prism cfg for instance path

  local cmd = string.format("for d in " .. instances .. "/*/; do basename \"$d\"; done")

  noctalia.runAsync(cmd, function(result)
    local instances = {}
    if result.exitCode == 0 and type(result.stdout) == "string" then
      for line in result.stdout:gmatch("[^\n]+") do
        local path = trim(line)
        if path ~= "" then
          table.insert(instances, path)
        end
      end
    end
    cachedInstances = instances
    onDone(instances)
  end)
end

local function filterInstances(instances, query)
  if query == "" then return instances end
  local lower = query:lower()
  local results = {}
  for _, path in instances do
    if path:lower():find(lower, 1, true) then
      table.insert(results, path)
    end
  end
  return results
end

local function makeRows(instances)
  local home = noctalia.getenv("HOME") or ""
  local rows = {}
  for _, path in instances do
    local display = (home ~= "" and path:sub(1, #home) == home)
      and "~" .. path:sub(#home + 1)
      or path
    table.insert(rows, {
      id = path,
      title = instanceName(path),
      subtitle = display,
      icon = getIcon(path),
      glyph = "nut",
    })
  end
  return rows
end

local function showResults(query, instances, filter)
  local filtered = filterInstances(instances, filter)
  if #filtered == 0 then
    launcher.setResults(query, {
      { id = "", title = "No instances found", subtitle = filter ~= "" and `Filter: "{filter}"` or "Zed database is empty or not found", glyph = "folder-x" }
    })
  else
    launcher.setResults(query, makeRows(filtered))
  end
end

function onQuery(query)
  local filter = trim(query)

  if cachedInstances then
    showResults(query, cachedInstances, filter)
    return
  end

  launcher.setResults(query, {
    { id = "", title = "Loading…", subtitle = "Reading PrismLauncher instances", glyph = "loader" }
  })

  loadInstances(function(instances)
    showResults(query, instances, filter)
  end)
end

function onActivate(id)
  if id == "" then return end
  noctalia.runAsync(string.format("prismlauncher --launch %s &>/dev/null", shellQuote(id)))
end

function getIcon(instancePath)
    -- TODO: fix custom icons, requires parsing instance config and fetching icon based on icon key
    return getPrismPath() .. "/instances/" .. instancePath .. "/minecraft/icon.png"
end
