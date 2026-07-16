currentThreshold = -1

function update()
  noctalia.setUpdateInterval(1000)
  getRate()
end

function getRateFile()
  local dev = "/sys/class/power_supply/BAT1" -- TODO(device-agnostic)
  return `{dev}/power_now`
end

function format(val)
    local num = tonumber(currentThreshold/1000/1000) or -3
    local decimals = noctalia.getConfig("decimal_places")
    local formatted = string.format("%."..tostring(decimals).."fW", num)
    return formatted
end

function getRate()
  local path = getRateFile()
  noctalia.runAsync(`sh -c "cat {path}"`, function(res)
    if res.exitCode == 0 then
      currentThreshold = res.stdout:gsub("%s+$", "")
    else
      currentThreshold = -2
      noctalia.log(`power-rate err: Failed to write power rate. exit code: {res.exitCode}`)
    end
    barWidget.setText(format(currentThreshold))
  end)
end
