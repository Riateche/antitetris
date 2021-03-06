local game = {}

local starting_adds_left = 0
local starting_adds_interval = 0.1
local adds_interval = 5
local floating_figure_update_interval = 0.05
local floating_check_interval = 0.5


local Value = {
  Free = 0,
  Solid = 1,
  Floating = 2,
  SolidMarked = 3,
}
game.Value = Value

local figures = {
  { { 1, 1, 1, 1 } }, -- I
  { { 1, 1 }, { 1, 1 } }, -- O
  { { 1, 1, 1 }, { 0, 1, 0 } }, -- T
  { { 1, 1, 1 }, { 0, 0, 1 } }, -- J
  { { 1, 1, 1 }, { 1, 0, 0 } }, -- L
  { { 0, 1, 1 }, { 1, 1, 0 } }, -- S
  { { 1, 1, 0 }, { 0, 1, 1 } } -- Z
}

local update_handlers = {}

local function table_find(table1, val)
  for i, v in ipairs(table1) do
    if v == val then
      return i
    end
  end
  return false
end

local function Timer(interval, callback)
  local obj = { interval = interval, callback = callback, elapsed = 0 }
  obj.update = function(dt)
    obj.elapsed = obj.elapsed + dt
      while obj.elapsed > obj.interval do
        obj.elapsed = obj.elapsed - obj.interval
        obj.callback()
      end
  end
  obj.start = function()
    if not table_find(update_handlers, obj.update) then
      table.insert(update_handlers, obj.update)
    end
  end
  obj.restart = function()
    obj.elapsed = 0
    obj.start()
  end
  obj.stop = function()
    local i = table_find(update_handlers, obj.update)
    if i then table.remove(update_handlers, i) end
  end
  return obj
end


game.field = {}
game.current_figure = nil
local x_selection = 1

local function fix_x_selection_bounds()
  if x_selection < 1 then
    x_selection = 1
  end
  local x_max = #game.field[1] - #game.current_figure[1] + 1
  if x_selection > x_max then
    x_selection = x_max
  end
end

local function is_removable_figure()
  local original_figure = game.current_figure
  local original_x_selection = x_selection
  for _ = 1, 4 do
    for x = 1, #game.field[1] do
      x_selection = x
      fix_x_selection_bounds()
      if game.can_remove_figure() then
        game.current_figure = original_figure
        x_selection = original_x_selection
        return true
      end
    end
    game.rotate_figure()
  end
  game.current_figure = original_figure
  x_selection = original_x_selection
  return false
end

local function get_field_item(x, y)
  if x < 1 or x > #game.field[1] or y < 1 or y > #game.field then
    return -1
  end
  return game.field[y][x]
end

local orphan_check_timer
orphan_check_timer = Timer(floating_check_interval, function()
  orphan_check_timer.stop()
  for x = 1, #game.field[1] do
    if game.field[#game.field][x] == Value.Solid then
      game.field[#game.field][x] = Value.SolidMarked
    end
  end
  while true do
    local changed = false
    for y = 1, #game.field do
      for x = 1, #game.field[y] do
        if game.field[y][x] == Value.Solid then
          if get_field_item(x, y-1) == Value.SolidMarked or
             get_field_item(x, y+1) == Value.SolidMarked or
             get_field_item(x-1, y) == Value.SolidMarked or
             get_field_item(x+1, y) == Value.SolidMarked then
            game.field[y][x] = Value.SolidMarked
            changed = true
          end
        end
      end
    end
    if not changed then
      break
    end
  end
  for y = 1, #game.field do
    for x = 1, #game.field[1] do
      if game.field[y][x] == Value.Solid then
        game.field[y][x] = Value.Floating
      elseif game.field[y][x] == Value.SolidMarked then
        game.field[y][x] = Value.Solid
      end
    end
  end
  if game.current_figure and not is_removable_figure() then
    game.generate_figure()
  end
end)

local function add_to_field()
  for x = 1, #game.field[1] do
    if game.field[1][x] == Value.Solid then
      -- game over
      game.start()
      return
    end
  end
  table.remove(game.field, 1)

  local new_line = {}
  for x = 1, #game.field[1] do
    if math.random() > 0.2 then
      new_line[x] = Value.Solid
    else
      new_line[x] = Value.Free
    end
  end
  table.insert(game.field, new_line)
  orphan_check_timer.restart()
end

local float_timer = Timer(floating_figure_update_interval, function()
  for x = 1, #game.field[1] do
    if game.field[1][x] == Value.Floating then
      -- float outside of the field
      game.field[1][x] = Value.Free
    end
  end
  for y = 2, #game.field do
    for x = 1, #game.field[y] do
      if game.field[y][x] == Value.Floating then
        if game.field[y - 1][x] == Value.Free then
          -- keep floating up
          game.field[y - 1][x] = Value.Floating
          game.field[y][x] = Value.Free
        else
          -- can't float! become solid
          game.field[y][x] = Value.Solid
        end
      end
    end
  end
end)

local add_timer
add_timer = Timer(starting_adds_interval, function()
  if starting_adds_left > 0 then
    starting_adds_left = starting_adds_left - 1
    if starting_adds_left == 0 then
      game.generate_figure()
      add_timer.interval = adds_interval
    end
  end
  add_to_field()
end)

function game.start()
  local field_size = { width = 10, height = 20 }
  for y = 1, field_size.height do
    game.field[y] = {}
    for x = 1, field_size.width do
      game.field[y][x] = Value.Free
    end
  end
  game.current_figure = nil
  starting_adds_left = math.floor(field_size.height / 3)

  add_timer.start();
  float_timer.start();

end

local function first_enabled_y(grid, x)
  for y = 1, #grid do
    if grid[y][x] == Value.Solid then
      return y
    end
  end
  return nil
end

local function calc_selection_y()
  local final_y = nil
  for x = 1, #game.current_figure[1] do
    local y1 = first_enabled_y(game.current_figure, x)
    local y2 = first_enabled_y(game.field, x + x_selection - 1)
    if y1 and y2 then
      local y = y2 - y1 + 1
      if final_y then
        final_y = math.max(final_y, y)
      else
        final_y = y
      end
    end
  end
  if final_y and final_y < #game.field - #game.current_figure + 1 then
    return final_y
  else
    return #game.field - #game.current_figure + 1
  end
end

function love.update(dt)
  for _, h in ipairs(update_handlers) do
    h(dt)
  end
end

local function round(x) return math.floor(x + 0.5) end

local function choose_figure()
  for _ = 1, 500 do
    game.current_figure = figures[math.random(1, #figures)]
    if is_removable_figure() then
      return
    end
  end
end

function game.generate_figure()
  choose_figure()
  x_selection = round((#game.field[1] - #game.current_figure[1]) / 2) + 1
end

function game.rotate_figure()
  local new_figure = {}
  for x = 1, #game.current_figure[1] do
    local line = {}
    for y = 1, #game.current_figure do
      table.insert(line, 1, game.current_figure[y][x])
    end
    table.insert(new_figure, line)
  end
  game.current_figure = new_figure
  if #new_figure == 1 then
    x_selection = x_selection - 1
  elseif #new_figure[1] == 1 then
    x_selection = x_selection + 1
  end
  fix_x_selection_bounds()
end



function game.can_remove_figure()
  local y_selection = calc_selection_y()
  if y_selection == nil then
    return false
  end
  for y = 1, #game.current_figure do
    for x = 1, #game.current_figure[1] do
      if game.current_figure[y][x] == Value.Solid and
         game.field[y + y_selection - 1][x + x_selection - 1] ~= game.current_figure[y][x] then
        return false
      end
    end
  end
  for x = 1, #game.current_figure[1] do
    local figure_top = first_enabled_y(game.current_figure, x) + y_selection - 1
    local field_top = first_enabled_y(game.field, x + x_selection - 1)
    if figure_top ~= field_top then
      return false
    end
  end
  return true
end

function game.remove_figure()
  if not game.can_remove_figure() then return false end
  local y_selection = calc_selection_y()
  for y = 1, #game.current_figure do
    for x = 1, #game.current_figure[1] do
      if game.current_figure[y][x] == Value.Solid then
        game.field[y + y_selection - 1][x + x_selection - 1] = Value.Floating
      end
    end
  end
  orphan_check_timer.restart()
  game.generate_figure()
  return true
end

function game.add_to_x_selection(d)
  x_selection = x_selection + d
  fix_x_selection_bounds()
end

function game.selection_pos()
  return { x = x_selection, y = calc_selection_y() }
end

return game
