function love.conf(t)
  t.identity = "po-backup"
  t.appendidentity = false
  t.version = "11.3"
  t.console = true
  t.accelerometerjoystick = false
  t.externalstorage = true 
  t.gammacorrect = false

  t.audio.mic = true
  t.audio.mixwithsystem = true

  t.window.title = "PO-BACKUP"
  t.window.icon = nil

  -- 2280 x 1080 
  t.window.width = 540
  t.window.height = 1140
  t.window.borderless = false
  t.window.resizable = true
  t.window.minwidth = 1
  t.window.minheight = 1
  t.window.fullscreen = false
  t.window.fullscreentype = "desktop"
  t.window.vsync = 1
  t.window.msaa = 0
  t.window.depth = nil
  t.window.stencil = nil
  t.window.display = 1
  t.window.highdpi = false
  t.window.usedpiscale = true
  t.window.x = nil
  t.window.y = nil

  t.modules.audio = true
  t.modules.data = true
  t.modules.event = true
  t.modules.font = true
  t.modules.graphics = true
  t.modules.image = true
  t.modules.joystick = false
  t.modules.keyboard = true
  t.modules.math = false
  t.modules.mouse = true
--  t.modules.physics = false
  t.modules.sound = true 
  t.modules.system = true
  t.modules.thread = true
  t.modules.timer = true
  t.modules.touch = true
--  t.modules.video = true
  t.modules.window = true
end

