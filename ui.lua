local ui = {}
local game = require("game")

local scale = 1

local solid_block_image = love.graphics.newImage("assets/solid.png")
local empty_block_image = love.graphics.newImage("assets/empty.png")
local highlight_block_image = love.graphics.newImage("assets/highlight.png")

local font = love.graphics.newFont("assets/DSEG7Classic-Regular.ttf", 25)
love.graphics.setFont(font)

local score_padding_top = 11
local field_offset = { x = 0, y = 42 }

local function draw_block(x, y, image)
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(
    image,
    field_offset.x + x * scale,
    field_offset.y + y * scale,
    0,
    scale / image:getWidth(),
    scale / image:getHeight())
end

function love.resize(width, height)
  local scale_x = width / #game.field[1]
  local scale_y = (height - field_offset.y) / #game.field
  scale = math.min(scale_x, scale_y)
  field_offset.x = (width - #game.field[1] * scale) / 2
end

function love.draw()
  local selection_pos
  if game.current_figure then
    selection_pos = game.selection_pos()
  end

  for y = 1, #game.field do
    for x = 1, #game.field[y] do
      local figure_x = selection_pos and (x - selection_pos.x + 1)
      local figure_y = selection_pos and (y - selection_pos.y + 1)
      local image = game.field[y][x] == game.Value.Free and empty_block_image or solid_block_image
      draw_block(x - 1, y - 1, image)
      if game.current_figure and
         figure_x > 0 and
         figure_x <= #game.current_figure[1] and
         figure_y > 0 and figure_y <= #game.current_figure then
        if game.current_figure[figure_y][figure_x] == game.Value.Solid then
          draw_block(x - 1, y - 1, highlight_block_image)
        end
      end
    end
  end

  love.graphics.printf("42", field_offset.x, score_padding_top, scale * #game.field[1], "right")
end

function ui.init()
  love.window.setMode(1024, 768, { resizable = true })
  local width, height = love.graphics.getDimensions()
  love.resize(width, height)
end

function love.keypressed(key, scancode, isrepeat)
  if game.current_figure then
    if key == "up" then
      game.remove_figure()
    elseif key == "r" then
      game.generate_figure()
    elseif key == "left" then
      game.add_to_x_selection(-1)
    elseif key == "right" then
      game.add_to_x_selection(1)
    elseif key == "rshift" then
      game.rotate_figure()
    end
  end
end

return ui
