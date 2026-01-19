minimapWidget = nil
minimapButton = nil
minimapWindow = nil
fullmapView = false
loaded = false
oldZoom = nil
oldPos = nil

function init()
  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRightPanel())
  minimapWindow:setContentMinimumHeight(64)

  if not minimapWindow.forceOpen then
    minimapButton = modules.client_topmenu.addRightGameToggleButton('minimapButton',
      tr('Minimap') .. ' (Ctrl+M)', '/images/topbuttons/minimap', toggle)
    minimapButton:setOn(true)
  end

  minimapWidget = minimapWindow:recursiveGetChildById('minimap')

  local gameRootPanel = modules.game_interface.getRootPanel()

  Keybind.new("Windows", "Toggle Minimap", "Ctrl+M", "")
  Keybind.new("UI", "Toggle Full Map", "Ctrl+Shift+M", "")

  Keybind.new("Minimap", "Center", "", "")
  Keybind.new("Minimap", "One Floor Down", "Alt+PageDown", "")
  Keybind.new("Minimap", "One Floor Up", "Alt+PageUp", "")
  Keybind.new("Minimap", "Scroll East", "Alt+Right", "")
  Keybind.new("Minimap", "Scroll North", "Alt+Up", "")
  Keybind.new("Minimap", "Scroll South", "Alt+Down", "")
  Keybind.new("Minimap", "Scroll West", "Alt+Left", "")
  Keybind.new("Minimap", "Zoom In", "Alt+End", "")
  Keybind.new("Minimap", "Zoom Out", "Alt+Home", "")

  Keybind.bind("Windows", "Toggle Minimap", {
    {
      type = KEY_DOWN,
      callback = toggle,
    }
  })
  Keybind.bind("UI", "Toggle Full Map", {
    {
      type = KEY_DOWN,
      callback = toggleFullMap,
    }
  })

  Keybind.bind("Minimap", "Center", {
    {
      type = KEY_DOWN,
      callback = reset,
    }
  })
  Keybind.bind("Minimap", "One Floor Down", {
    {
      type = KEY_DOWN,
      callback = floorDown,
    }
  })
  Keybind.bind("Minimap", "One Floor Up", {
    {
      type = KEY_DOWN,
      callback = floorUp,
    }
  })
  Keybind.bind("Minimap", "Scroll East", {
    {
      type = KEY_PRESS,
      callback = function() minimapWidget:move(-1, 0) end,
    }
  }, gameRootPanel)
  Keybind.bind("Minimap", "Scroll North", {
    {
      type = KEY_PRESS,
      callback = function() minimapWidget:move(0, 1) end,
    }
  }, gameRootPanel)
  Keybind.bind("Minimap", "Scroll South", {
    {
      type = KEY_PRESS,
      callback = function() minimapWidget:move(0, -1) end,
    }
  }, gameRootPanel)
  Keybind.bind("Minimap", "Scroll West", {
    {
      type = KEY_PRESS,
      callback = function() minimapWidget:move(1, 0) end,
    }
  }, gameRootPanel)
  Keybind.bind("Minimap", "Zoom In", {
    {
      type = KEY_DOWN,
      callback = zoomIn,
    }
  })
  Keybind.bind("Minimap", "Zoom Out", {
    {
      type = KEY_DOWN,
      callback = zoomOut,
    }
  })

  minimapWindow:setup()

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  if g_game.isOnline() then
    saveMap()
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  Keybind.delete("Windows", "Toggle Minimap")
  Keybind.delete("UI", "Toggle Full Map")

  Keybind.delete("Minimap", "Center")
  Keybind.delete("Minimap", "One Floor Down")
  Keybind.delete("Minimap", "One Floor Up")
  Keybind.delete("Minimap", "Scroll East")
  Keybind.delete("Minimap", "Scroll North")
  Keybind.delete("Minimap", "Scroll South")
  Keybind.delete("Minimap", "Scroll West")
  Keybind.delete("Minimap", "Zoom In")
  Keybind.delete("Minimap", "Zoom Out")

  minimapWindow:destroy()
  if minimapButton then
    minimapButton:destroy()
  end
end

function toggle()
  if not minimapButton then return end
  if minimapButton:isOn() then
    minimapWindow:close()
    minimapButton:setOn(false)
  else
    minimapWindow:open()
    minimapButton:setOn(true)
  end
end

function onMiniWindowClose()
  if minimapButton then
    minimapButton:setOn(false)
  end
end

function online()
  loadMap()
  updateCameraPosition()
end

function offline()
  saveMap()
end

function loadMap()
  local clientVersion = g_game.getClientVersion()

  g_minimap.clean()
  loaded = false

  local minimapFile = '/minimap.otmm'
  local versionedMinimapFile = '/minimap' .. clientVersion .. '.otmm'
  local dataMinimapFile = '/data/minimap' .. versionedMinimapFile

  print(string.format("Checking minimap files - AppData: %s, Data: %s", versionedMinimapFile, dataMinimapFile))

  -- Função auxiliar para obter o tamanho do arquivo
  -- Como arquivos .otmm podem estar criptografados/comprimidos, tentamos ler o tamanho
  -- mas se falhar, marcamos como -1 para tentar carregar diretamente depois
  local function getFileSize(filePath)
    if not g_resources.fileExists(filePath) then
      print(string.format("File does not exist: %s", filePath))
      return 0
    end

    -- Tenta ler o arquivo para obter o tamanho
    local success, content = pcall(function() return g_resources.readFileContents(filePath) end)
    if success and content and type(content) == "string" then
      local size = #content
      print(string.format("File size for %s: %d bytes", filePath, size))
      return size
    else
      -- Arquivo pode estar criptografado/comprimido, não conseguimos ler diretamente
      -- Mas sabemos que existe, então retornamos -1 para indicar que devemos tentar carregar
      print(string.format("File exists but could not read size for %s (may be encrypted/compressed)", filePath))
      return -1 -- -1 indica que o arquivo existe mas não conseguimos ler o tamanho
    end
  end

  -- Verificar existência dos arquivos
  local appdataExists = g_resources.fileExists(versionedMinimapFile)
  local dataExists = g_resources.fileExists(dataMinimapFile)

  print(string.format("File existence - AppData: %s, Data: %s",
    appdataExists and "exists" or "not found",
    dataExists and "exists" or "not found"))

  -- Comparar tamanhos dos arquivos e carregar o maior
  local appdataSize = appdataExists and getFileSize(versionedMinimapFile) or 0
  local dataSize = dataExists and getFileSize(dataMinimapFile) or 0

  print(string.format("File sizes - AppData: %d bytes, Data: %d bytes", appdataSize, dataSize))

  -- Se não conseguimos obter os tamanhos mas os arquivos existem, tenta carregar ambos
  if (appdataSize == -1 or dataSize == -1) and (appdataExists or dataExists) then
    print("Could not determine file sizes, trying to load both files to compare...")
    -- Tenta carregar o de /data/minimap primeiro
    if dataExists then
      print("Attempting to load from /data/minimap...")
      local tempLoaded = g_minimap.loadOtmm(dataMinimapFile)
      if tempLoaded then
        print("Successfully loaded from /data/minimap, using this file")
        loaded = true
      end
    end
    -- Se não carregou de /data/minimap, tenta appdata
    if not loaded and appdataExists then
      print("Attempting to load from appdata...")
      loaded = g_minimap.loadOtmm(versionedMinimapFile)
      if loaded then
        print("Successfully loaded from appdata")
      end
    end
  elseif appdataSize > 0 or dataSize > 0 then
    if dataSize >= appdataSize and dataSize > 0 then
      -- Prioriza arquivo em /data/minimap se for maior ou igual
      print(string.format("Loading minimap from /data/minimap (size: %d bytes)", dataSize))
      loaded = g_minimap.loadOtmm(dataMinimapFile)
      if loaded then
        print(string.format("Minimap loaded successfully from /data/minimap%s", versionedMinimapFile))
      else
        print(string.format("Failed to load minimap from /data/minimap%s, trying appdata...", versionedMinimapFile))
        -- Se falhar, tenta carregar do appdata
        if appdataSize > 0 then
          loaded = g_minimap.loadOtmm(versionedMinimapFile)
          if loaded then
            print(string.format("Minimap loaded successfully from appdata%s", versionedMinimapFile))
          end
        end
      end
    elseif appdataSize > 0 then
      print(string.format("Loading minimap from appdata (size: %d bytes)", appdataSize))
      loaded = g_minimap.loadOtmm(versionedMinimapFile)
      if loaded then
        print(string.format("Minimap loaded successfully from appdata%s", versionedMinimapFile))
      else
        print(string.format("Failed to load minimap from appdata%s", versionedMinimapFile))
      end
    end
  else
    print("Both minimap files have size 0 or do not exist")
  end

  -- Fallback para arquivos antigos
  if not loaded and g_resources.fileExists(minimapFile) then
    print("Loading minimap from fallback location: /minimap.otmm")
    loaded = g_minimap.loadOtmm(minimapFile)
    if loaded then
      print("Minimap loaded successfully from /minimap.otmm")
    end
  end

  if not loaded then
    print("Minimap couldn't be loaded, file missing?")
  end
  minimapWidget:load()
end

function saveMap()
  local clientVersion = g_game.getClientVersion()
  local minimapFile = '/minimap' .. clientVersion .. '.otmm'
  g_minimap.saveOtmm(minimapFile)
  minimapWidget:save()
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if not pos then return end
  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(player:getPosition())
    end
    minimapWidget:setCrossPosition(player:getPosition())
  end
end

function toggleFullMap()
  if not fullmapView then
    fullmapView = true
    minimapWindow:hide()
    minimapWidget:setParent(modules.game_interface.getRootPanel())
    minimapWidget:fill('parent')
    minimapWidget:setAlternativeWidgetsVisible(true)
  else
    fullmapView = false
    minimapWidget:setParent(minimapWindow:getChildById('contentsPanel'))
    minimapWidget:fill('parent')
    minimapWindow:show()
    minimapWidget:setAlternativeWidgetsVisible(false)
  end

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end

function center()
  minimapWidget:reset()
end

function floorDown()
  minimapWidget:floorDown(1)
end

function floorUp()
  minimapWidget:floorUp(1)
end

function zoomIn()
  minimapWidget:zoomIn()
end

function zoomOut()
  minimapWidget:zoomOut()
end
