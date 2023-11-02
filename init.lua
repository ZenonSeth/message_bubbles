local shown = {}

local settings = minetest.settings
local MSG_BUBBLE_LIFETIME = tonumber(settings:get("message_bubbles_lifetime")) or 10
local MAX_CHARS_PER_LINE = tonumber(settings:get("message_bubbles_char_limit")) or 40
local MAX_NUM_LINES = tonumber(settings:get("message_bubbles_max_num_lines")) or 1
local MSG_BUBBLE_PREFIX = settings:get("message_bubbles_prefix") or "Says: "

local cumulativeTime = 0

local function trim(msg)
  if not msg or not type(msg) == "string" then return "" end
  if string.len(msg) <= MAX_CHARS_PER_LINE then return msg end
  if MAX_NUM_LINES <= 1 then return string.sub(msg, 1, MAX_CHARS_PER_LINE)..".." end

  -- else: we have multilines to split
  local words = string.split(msg, " ", false)
  local ret = ""
  local currLine = 1
  local wordIndex = 1
  local line = ""
  while currLine <= MAX_NUM_LINES do
    local adjMaxChPerLine = MAX_CHARS_PER_LINE
    if currLine == 1 then adjMaxChPerLine = MAX_CHARS_PER_LINE - string.len(MSG_BUBBLE_PREFIX) end
    local space = ""
    if string.len(line) > 0 then space = " " end
    local tmp = line..space
    if words[wordIndex] then
      tmp = line..space..words[wordIndex]
    else -- we used all the words, return early
      currLine = MAX_NUM_LINES + 1
      return ret..line
    end

    if string.len(tmp) <= adjMaxChPerLine then
      -- adding this word didn't overflow the line length
      line = tmp
      wordIndex = wordIndex + 1
    else -- the word pushed the line length over the limit
      if currLine == MAX_NUM_LINES then
        -- last line, just cut last word and return early
        line = string.sub(tmp, 1, adjMaxChPerLine)
        return ret..line..".."
      else
        -- don't add the word, leave it to the next line (don't increment wordIndex)
        ret = ret..line.."\n"
      end
      line = ""
      currLine = currLine + 1
    end
  end
  return ret
end

minetest.register_on_chat_message(function(name, origMessage)
  if minetest.get_player_privs(name).shout then
    local player = minetest.get_player_by_name(name)
    if not player then return end
    local msg = "\n"..MSG_BUBBLE_PREFIX..trim(origMessage)
    local nametag = player:get_nametag_attributes()
    local nametagText = nametag.text
    local hadToAddName = false
    if shown[name] then
      local currText = shown[name].text
      if shown[name].wasEmpty then
        shown[name].text = name..msg
        shown[name].addedMsg = msg
      else
        shown[name].text = string.gsub(nametagText, currText, msg)
        shown[name].addedMsg = msg
      end
      shown[name].time = minetest.get_gametime()
    else
      local addedMsg = msg
      if not nametagText or nametagText == "" then
        msg = name..msg
        hadToAddName = true
      end
      shown[name] = {
        text = msg,
        addedMsg = addedMsg,
        time = minetest.get_gametime(),
        wasEmpty = hadToAddName,
      }
    end
    nametag.text = shown[name].text
    player:set_nametag_attributes(nametag)
  end
end)

minetest.register_globalstep(function(dtime)
  cumulativeTime = cumulativeTime + dtime
  if cumulativeTime > 1 then
    cumulativeTime = 0
    local currTime = minetest.get_gametime()
    for playerName, info in pairs(shown) do
      if currTime - info.time > MSG_BUBBLE_LIFETIME then
        local player = minetest.get_player_by_name(playerName)
        if player then
          local nametag = player:get_nametag_attributes()
          if info.wasEmpty then
            nametag.text = ""
          else
            nametag.text = string.gsub(nametag.text, info.addedMsg, "")
          end
          player:set_nametag_attributes(nametag)
        end
        shown[playerName] = nil
      end
    end
  end
end)