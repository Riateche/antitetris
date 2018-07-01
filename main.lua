local colors = {
  inactive = { 60, 60, 60 },
  active = { 255, 255, 255 },
  selected = { 150, 255, 150 }
}

local scale = 1

local field_size = { width = 10, height = 20 }
local field = {}

local time_since_last_add = 0
local starting_adds_left = 0
local starting_adds_interval = 0.1
local adds_interval = 4

local time_since_floating_figure_update = 0
local floating_figure_update_interval = 0.05

local time_since_floating_check_request = nil
local floating_check_interval = 0.5

local figures = {}

local Value = {
  Free = 0,
  Solid = 1,
  Floating = 2,
  SolidMarked = 3,
}

figures[1] = {
  { { 1 } } -- single block
}
figures[2] = {
  { { 1, 1 } } -- domino
}
figures[3] = {
  { { 1, 1, 1 } }, -- I
  { { 1, 1 }, { 1, 0 } } -- L
}
figures[4] = {
  { { 1, 1, 1, 1 } }, -- I
  { { 1, 1 }, { 1, 1 } }, -- O
  { { 1, 1, 1 }, { 0, 1, 0 } }, -- T
  { { 1, 1, 1 }, { 0, 0, 1 } }, -- J
  { { 1, 1, 1 }, { 1, 0, 0 } }, -- L
  { { 0, 1, 1 }, { 1, 1, 0 } }, -- S
  { { 1, 1, 0 }, { 0, 1, 1 } } -- Z
}

local figure = nil

function start_game()
  for y = 1, field_size.height do
    field[y] = {}
    for x = 1, field_size.width do
      field[y][x] = Value.Free
    end
  end
  figure = nil
  starting_adds_left = math.floor(field_size.height / 3)
end

love.resize = function(width, height)
  local scale_x = width / (field_size.width + 5)
  local scale_y = height / field_size.height
  scale = math.min(scale_x, scale_y)
end


function draw_rect(x, y, color, highlight)
  if highlight then
    love.graphics.setColor(highlight)
  else
    love.graphics.setColor(color)
  end
  local d = scale / 20
  love.graphics.rectangle("fill", x * scale + d, y * scale + d, scale - d * 2, scale - d * 2)
  love.graphics.setColor(color[1] / 2, color[2] / 2, color[3] / 2)
  d = d + scale / 10
  love.graphics.rectangle("fill", x * scale + d, y * scale + d, scale - d * 2, scale - d * 2)
  love.graphics.setColor(color)
  d = d + scale / 10
  love.graphics.rectangle("fill", x * scale + d, y * scale + d, scale - d * 2, scale - d * 2)
end


local x_selection = 1

function first_enabled_y(grid, x)
  for y = 1, #grid do
    if grid[y][x] == Value.Solid then
      return y
    end
  end
  return nil
end

function calc_selection_y()
  local final_y = nil
  for x = 1, #figure[1] do
    local y1 = first_enabled_y(figure, x)
    local y2 = first_enabled_y(field, x + x_selection - 1)
    if y1 and y2 then
      local y = y2 - y1 + 1
      if final_y then
        final_y = math.max(final_y, y)
      else
        final_y = y
      end
    end
  end
  if final_y and final_y < #field - #figure + 1 then
    return final_y
  else
    return #field - #figure + 1
  end
end


function love.draw()
  local color
  local y_selection = nil
  if figure then
    y_selection = calc_selection_y()
  end

  for y = 1, field_size.height do
    for x = 1, field_size.width do
      local figure_x = x - x_selection + 1
      local figure_y = y_selection and (y - y_selection + 1)
      local figure_matches = false
      local highlight = nil
      if figure and figure_x > 0 and figure_x <= #figure[1] and figure_y > 0 and figure_y <= #figure then
        if figure[figure_y][figure_x] == Value.Solid then
          if field[y][x] == Value.Solid then
            color = colors.selected
          else
            color = colors.inactive
            highlight = colors.selected
          end
          figure_matches = true
        end
      end
      if not figure_matches then
        if field[y][x] ~= Value.Free then
          color = colors.active
        else
          color = colors.inactive
        end
      end
      draw_rect(x - 1, y - 1, color, highlight);
    end
  end

  if figure then
    for y = 1, #figure do
      for x = 1, #figure[1] do
        local color
        if figure[y][x] == Value.Solid then
          color = colors.selected
        else
          color = colors.inactive
        end
        draw_rect(x + field_size.width, y - 1, color);
      end
    end
  end
end


function love.update(dt)
  time_since_last_add = time_since_last_add + dt
  if starting_adds_left > 0 then
    if time_since_last_add > starting_adds_interval then
      add_to_field()
      time_since_last_add = time_since_last_add - starting_adds_interval
      starting_adds_left = starting_adds_left - 1
      if starting_adds_left == 0 then
        generate_figure()
      end
    end
  else
    if time_since_last_add > adds_interval then
      add_to_field()
      time_since_last_add = time_since_last_add - adds_interval
    end
  end

  time_since_floating_figure_update = time_since_floating_figure_update + dt
  if time_since_floating_figure_update > floating_figure_update_interval then
    time_since_floating_figure_update = time_since_floating_figure_update - floating_figure_update_interval
    for x = 1, field_size.width do
      if field[1][x] == Value.Floating then
        field[1][x] = Value.Free
      end
    end
    for y = 2, field_size.height do
      for x = 1, field_size.width do
        if field[y][x] == Value.Floating then
          field[y - 1][x] = Value.Floating
          field[y][x] = Value.Free
        end
      end
    end
  end
  if time_since_floating_check_request then
    time_since_floating_check_request = time_since_floating_check_request + dt
    if time_since_floating_check_request > floating_check_interval then
      time_since_floating_check_request = nil
      mark_orphans()
    end
  end

end

function love.load()
  math.randomseed(4242)
  start_game()
  love.window.setMode(1024, 768, { resizable = true })
  local width, height = love.graphics.getDimensions()
  love.resize(width, height)
end

function is_empty_line(y)
  for x = 1, field_size.width do
    if field[y][x] ~= Value.Free then
      return false
    end
  end
  return true
end

function add_to_field()
  local has_empty_line = false
  for y = field_size.height, 1, -1 do
    if is_empty_line(y) then
      table.remove(field, y)
      has_empty_line = true
      break
    end
  end
  if not has_empty_line then
    -- game over
    start_game()
    return
  end
  new_line = {}
  for x = 1, field_size.width do
    if math.random() > 0.2 then
      new_line[x] = Value.Solid
    else
      new_line[x] = Value.Free
    end
  end
  table.insert(field, new_line)
  time_since_floating_check_request = 0
  -- mark_orphans()
end

function round(x) return math.floor(x + 0.5) end

function is_removable_figure()
  local original_figure = figure
  for _ = 1, 4 do
    for x = 1, field_size.width do
      x_selection = x
      fix_x_selection_bounds()
      if can_remove_figure() then
        figure = original_figure
        return true
      end
    end
    rotate_figure()
  end
  figure = original_figure
  return false
end

function choose_figure()
  --local start_d
  --local roll = math.random()
  --if roll < 0.2 then
  --  start_d = 1
  --elseif roll < 0.3 then
  --  start_d = 2
  --elseif roll < 0.4 then
  --  start_d = 3
  --else
  --start_d = 4
  --end
  --local d = start_d
  --for d = start_d, 1, -1 do
  local d = 4
  for _ = 1, 500 do
    figure = figures[d][math.random(1, #figures[d])]
    if is_removable_figure() then
      return
    end
  end
  --end
  --figure = figures[1][1]
end

function generate_figure()
  choose_figure()
  x_selection = round((#field[1] - #figure[1]) / 2) + 1
end

function rotate_figure()
  new_figure = {}
  for x = 1, #figure[1] do
    local line = {}
    for y = 1, #figure do
      table.insert(line, 1, figure[y][x])
    end
    table.insert(new_figure, line)
  end
  figure = new_figure
  if #new_figure == 1 then
    x_selection = x_selection - 1
  elseif #new_figure[1] == 1 then
    x_selection = x_selection + 1
  end
  fix_x_selection_bounds()
end

function fix_x_selection_bounds()
  if x_selection < 1 then
    x_selection = 1
  end
  local x_max = #field[1] - #figure[1] + 1
  if x_selection > x_max then
    x_selection = x_max
  end
end

function can_remove_figure()
  local y_selection = calc_selection_y()
  if y_selection == nil then
    return false
  end
  for y = 1, #figure do
    for x = 1, #figure[1] do
      if figure[y][x] == Value.Solid and field[y + y_selection - 1][x + x_selection - 1] ~= figure[y][x] then
        return false
      end
    end
  end
  for x = 1, #figure[1] do
    local figure_top = first_enabled_y(figure, x) + y_selection - 1
    local field_top = first_enabled_y(field, x + x_selection - 1)
    if figure_top ~= field_top then
      return false
    end
  end
  return true
end

function field_get_item(x, y)
  if x < 1 or x > field_size.width or y < 1 or y > field_size.height then
    return -1
  end
  return field[y][x]
end

function mark_orphans()
  local marked = {}
  for x = 1, field_size.width do
    if field[field_size.height][x] == Value.Solid then
      field[field_size.height][x] = Value.SolidMarked
    end
  end
  while true do
    local changed = false
    for y = 1, field_size.height do
      for x = 1, field_size.width do
        if field[y][x] == Value.Solid then
          if field_get_item(x, y-1) == Value.SolidMarked or
             field_get_item(x, y+1) == Value.SolidMarked or
             field_get_item(x-1, y) == Value.SolidMarked or
             field_get_item(x+1, y) == Value.SolidMarked then
            field[y][x] = Value.SolidMarked
            changed = true
          end
        end
      end
    end
    if not changed then
      break
    end
  end
  for y = 1, field_size.height do
    for x = 1, field_size.width do
      if field[y][x] == Value.Solid then
        field[y][x] = Value.Floating
      elseif field[y][x] == Value.SolidMarked then
        field[y][x] = Value.Solid
      end
    end
  end
end

function remove_figure()
  if not can_remove_figure() then return false end
  local y_selection = calc_selection_y()
  for y = 1, #figure do
    for x = 1, #figure[1] do
      if figure[y][x] == Value.Solid then
        field[y + y_selection - 1][x + x_selection - 1] = Value.Floating
      end
    end
  end
  --mark_orphans()
  time_since_floating_check_request = 0
  --time_since_floating_figure_update = 0
  generate_figure()
  return true
end

function love.keypressed(key, scancode, isrepeat)
  if figure then
    if key == "up" then
      remove_figure()
    elseif key == "r" then
      generate_figure()
    elseif key == "left" then
      x_selection = x_selection - 1
      fix_x_selection_bounds()
    elseif key == "right" then
      x_selection = x_selection + 1
      fix_x_selection_bounds()
    elseif key == "rshift" then
      rotate_figure()
    end
  end
end
