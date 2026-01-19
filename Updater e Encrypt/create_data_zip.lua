-- Script para criar data.zip usando a função nativa do cliente
-- Este script será executado automaticamente pelo build-release.sh

local function collectFilesRecursive(path, prefix, files)
  prefix = prefix or ""
  files = files or {}

  if not g_resources.directoryExists(path) and not g_resources.fileExists(path) then
    return files
  end

  if g_resources.fileExists(path) then
    -- É um arquivo
    local fileName = prefix == "" and path or prefix
    files[fileName] = g_resources.readFileContents(path)
    return files
  end

  -- É um diretório
  local dirFiles = g_resources.listDirectoryFiles(path)
  for _, file in ipairs(dirFiles) do
    local fullPath = path .. "/" .. file
    local filePath = prefix == "" and file or prefix .. "/" .. file

    if g_resources.fileExists(fullPath) then
      -- Arquivo regular
      files[filePath] = g_resources.readFileContents(fullPath)
    elseif g_resources.directoryExists(fullPath) then
      -- Subdiretório - recursão
      collectFilesRecursive(fullPath, filePath, files)
    end
  end

  return files
end

local function createDataZip()
  g_logger.info("Iniciando criação do data.zip...")

  local files = {}

  -- Coletar init.lua do backup (original), não o temporário
  if g_resources.fileExists("init.lua.backup") then
    files["init.lua"] = g_resources.readFileContents("init.lua.backup")
    g_logger.info("Adicionado: init.lua (do backup original)")
  elseif g_resources.fileExists("init.lua") then
    -- Fallback: usar init.lua atual se backup não existir
    files["init.lua"] = g_resources.readFileContents("init.lua")
    g_logger.info("Adicionado: init.lua")
  end

  -- Coletar pastas
  local folders = { "data", "modules", "layouts", "mods" }
  for _, folder in ipairs(folders) do
    if g_resources.directoryExists(folder) then
      g_logger.info("Coletando arquivos de: " .. folder)
      collectFilesRecursive(folder, folder, files)
    end
  end

  local count = 0
  for _ in pairs(files) do count = count + 1 end
  g_logger.info("Total de arquivos coletados: " .. count)

  -- Criar o arquivo zip
  g_logger.info("Criando arquivo zip...")
  local zipData = g_resources.createArchive(files)

  if not zipData or zipData == "" then
    g_logger.error("Erro ao criar data.zip")
    g_app.quick_exit()
    return false
  end

  -- Salvar o arquivo no diretório de escrita
  g_logger.info("Salvando data.zip...")
  g_resources.writeFileContents("data.zip", zipData)

  g_logger.info("data.zip criado com sucesso! Tamanho: " .. #zipData .. " bytes")

  -- Fechar o cliente após criar o arquivo (aguardar um pouco para garantir que o arquivo foi salvo)
  scheduleEvent(function()
    g_logger.info("Fechando cliente...")
    g_app.quick_exit()
  end, 500)

  return true
end

-- Executar após um pequeno delay para garantir que tudo foi inicializado
scheduleEvent(function()
  createDataZip()
end, 1000)
