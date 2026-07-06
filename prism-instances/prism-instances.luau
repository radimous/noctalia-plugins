-- based on https://github.com/Cleboost/noctalia-plugins/blob/main/zed-projects/zed_projects.luau

prismPath = "~/.local/share/PrismLauncher" -- TODO(config)
local function getPrismPath()
    return noctalia.expandPath(prismPath)
end

local function trim(s)
  return (s:match("^%s*(.-)%s*$"))
end

local function instanceName(path)
  return path:match("([^/]+)$") or path
end

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\"'\"'") .. "'"
end

local function getInstanceDir()
    local prism = getPrismPath()

    local instanceDir = getValue(prism .. "/prismlauncher.cfg", "InstanceDir")

    local instances
    if instanceDir == nil then
        instances = prism .. "/instances"
        else
        instances = prism .. "/" .. instanceDir
    end
    return instances
end

local function loadInstances(onDone)
   local cmd = string.format("for d in " .. getInstanceDir() .. "/*/; do basename \"$d\"; done")

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
      { id = "", title = "No instances found", subtitle = filter ~= "" and `Filter: "{filter}"`, glyph = "folder-x" }
    })
  else
    launcher.setResults(query, makeRows(filtered))
  end
end

function onQuery(query)
  local filter = trim(query)

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

function getIcon(instanceName)
    local instancePath = getInstanceDir() .. "/" .. instanceName
    local defaultIcon =  instancePath .. "/minecraft/icon.png"
    local cfgPath = instancePath .. "/instance.cfg"
    local iconVal = getValue(cfgPath, "iconKey")
    if (iconVal == nil) then
        return defaultIcon
    end

    local iconDir = getPrismPath() .. "/icons/"
    local bestIcon = findBestIconIn(iconDir, iconVal)

    if (bestIcon == nil) then
        return defaultIcon
    end
    return bestIcon
end



function getValue(cfgPath, key)
    local content, err = noctalia.readFile(cfgPath)
    if not content then
        noctalia.log("Failed to read file ".. cfgPath .. " : " .. tostring(err))
        return nil
    end

    for line in content:gmatch("[^\r\n]+") do
        if line:sub(1, #key + 1) == key .. "=" then
            return line:sub(#key + 2)
        end
    end

    return nil
end

-- https://github.com/PrismLauncher/PrismLauncher/blob/d2fa7cf7f7aa8fa5e3d4f5f7b474621c732cd525/launcher/icons/IconUtils.cpp
local validIconExtensions = { "svg", "png", "ico", "gif", "jpg", "jpeg", "webp" }

local function isIconSuffix(suffix)
    for _, ext in ipairs(validIconExtensions) do
        if ext == suffix then
            return true
        end
    end
    return false
end


local function splitNameAndSuffix(filename)
    local dotIndex = filename:find("%.[^.]*$")
    if not dotIndex then
        return filename, ""
    end
    local base = filename:sub(1, dotIndex - 1)
    local suffix = filename:sub(dotIndex + 1)
    return base, suffix
end

function findBestIconIn(folder, iconKey)
    local entries = noctalia.listDir(folder)
    if not entries then
        return nil
    end

    for _, filename in ipairs(entries) do
        local baseName, suffix = splitNameAndSuffix(filename)
        if (baseName == iconKey or filename == iconKey) and isIconSuffix(suffix) then
            local sep = folder:sub(-1) == "/" and "" or "/"
            return folder .. sep .. filename
        end
    end

    return nil
end
