local ui = require("ui")
local game = require("game")

function love.load()
  math.randomseed(os.time())
  game.start()
  ui.init()
end



