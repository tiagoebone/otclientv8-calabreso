#!/bin/bash
set -euo pipefail

echo "🚀 Iniciando build do release do Calabreso..."

# --- caminhos (script FORA da pasta Calabreso) ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLIENT_DIR="$SCRIPT_DIR/Calabreso"        # pasta original (mantida)
WORK_DIR="$SCRIPT_DIR/Calabreso_copy"     # cópia temporária
RELEASE_DIR="$SCRIPT_DIR/release"         # saída final ao lado
EXE_NAME="Calabreso"

# --- checagens ---
if [[ ! -d "$CLIENT_DIR" ]]; then
  echo "❌ Erro: pasta '$CLIENT_DIR' não encontrada."
  exit 1
fi
EXE_PATH="$EXE_NAME"
[[ -f "$CLIENT_DIR/$EXE_NAME.exe" ]] && EXE_PATH="$EXE_NAME.exe"
if [[ ! -f "$CLIENT_DIR/$EXE_NAME" && ! -f "$CLIENT_DIR/$EXE_NAME.exe" ]]; then
  echo "❌ Executável '$EXE_NAME' não encontrado dentro de 'Calabreso/'."
  exit 1
fi
command -v cygpath >/dev/null || { echo "❌ 'cygpath' não encontrado (use Git Bash)."; exit 1; }

# --- 1) criar cópia da pasta Calabreso ---
echo "📦 Criando cópia em '$WORK_DIR'..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -r "$CLIENT_DIR"/* "$WORK_DIR"/
# limpa arquivos de controle (se existirem)
rm -rf "$WORK_DIR/.git" "$WORK_DIR/.github" "$WORK_DIR/.gitignore" "$WORK_DIR/.gitattributes" "$WORK_DIR/README.md" "$WORK_DIR/readme.md" "$WORK_DIR/docs" 2>/dev/null || true
echo "✅ Cópia criada."

# --- 2) dentro da cópia: encrypt ---
echo "🔐 Criptografando dentro da cópia..."
# Senha de criptografia (altere esta senha se necessário)
ENCRYPT_PASSWORD='K7#mP9@xQ2$vL4&nR8!wT5%zY3^bN6'
pushd "$WORK_DIR" >/dev/null
chmod +x "./$EXE_PATH" 2>/dev/null || true
"./$EXE_PATH" --encrypt "$ENCRYPT_PASSWORD"
echo "✅ Criptografia concluída!"
popd >/dev/null

# --- 3) criar data.zip usando função nativa do cliente ---
echo "🗜️  Criando data.zip usando função nativa do cliente..."

# Verificar se as pastas necessárias existem
if [[ ! -f "$WORK_DIR/init.lua" ]]; then
  echo "❌ Erro: init.lua não encontrado em '$WORK_DIR'."
  rm -rf "$WORK_DIR"; exit 1
fi

# Copiar script create_data_zip.lua para a pasta de trabalho
SCRIPT_DIR_WIN=$(cygpath -w "$SCRIPT_DIR")
if [[ -f "$SCRIPT_DIR/create_data_zip.lua" ]]; then
  cp "$SCRIPT_DIR/create_data_zip.lua" "$WORK_DIR/"
  echo "  ✓ Script create_data_zip.lua copiado"
else
  echo "❌ Erro: create_data_zip.lua não encontrado em '$SCRIPT_DIR'."
  rm -rf "$WORK_DIR"; exit 1
fi

# Fazer backup do init.lua original
cp "$WORK_DIR/init.lua" "$WORK_DIR/init.lua.backup"

# Criar init.lua temporário que executa o script e fecha o cliente
cat > "$WORK_DIR/init.lua" << 'INIT_EOF'
-- CONFIG
APP_NAME = "Calabresot"
APP_VERSION = 1341
DEFAULT_LAYOUT = "retro"

Services = {
  website = "http://otclient.ovh",
  updater = "",
  stats = "",
  crash = "",
  feedback = "",
  status = ""
}

Servers = {
  Calabreso = "181.215.236.209:7171:800",
  TestServer = "127.0.0.1:7171:800"
}

ALLOW_CUSTOM_SERVERS = true
g_app.setName("OTCv8")

-- print first terminal message
g_logger.info(os.date("== application started at %b %d %Y %X"))

if not g_resources.directoryExists("/data") then
  g_logger.fatal("Data dir doesn't exist.")
end

if not g_resources.directoryExists("/modules") then
  g_logger.fatal("Modules dir doesn't exist.")
end

-- settings
g_configs.loadSettings("/config.otml")

-- set layout
local settings = g_configs.getSettings()
local layout = DEFAULT_LAYOUT
if g_app.isMobile() then
  layout = "mobile"
elseif settings:exists('layout') then
  layout = settings:getValue('layout')
end
g_resources.setLayout(layout)

-- load mods
g_modules.discoverModules()
g_modules.ensureModuleLoaded("corelib")

-- Executar script para criar data.zip e fechar
scheduleEvent(function()
  if g_resources.fileExists("create_data_zip.lua") then
    dofile("create_data_zip.lua")
  else
    g_logger.error("create_data_zip.lua não encontrado!")
    g_app.quick_exit()
  end
end, 500)
INIT_EOF

echo "  ✓ init.lua temporário criado"

# Executar o cliente e esperar ele fechar
echo "  ⏳ Executando cliente para criar data.zip..."
WORK_DIR_WIN=$(cygpath -w "$WORK_DIR")
EXE_PATH_WIN=$(cygpath -w "$WORK_DIR/$EXE_PATH")

# Usar PowerShell para executar o cliente e aguardar
powershell.exe -NoProfile -Command "
  Set-Location -LiteralPath '$WORK_DIR_WIN'
  \$process = Start-Process -FilePath '$EXE_PATH_WIN' -WorkingDirectory '$WORK_DIR_WIN' -PassThru -WindowStyle Hidden
  Write-Host '  ⏳ Aguardando cliente criar data.zip (PID: ' \$process.Id ')...'
  
  # Aguardar até 60 segundos
  \$timeout = 60
  \$elapsed = 0
  while (-not \$process.HasExited -and \$elapsed -lt \$timeout) {
    Start-Sleep -Seconds 1
    \$elapsed++
  }
  
  if (-not \$process.HasExited) {
    Write-Host '  ⚠ Cliente ainda está rodando após ' \$timeout ' segundos. Tentando encerrar...'
    Stop-Process -Id \$process.Id -Force -ErrorAction SilentlyContinue
  } else {
    Write-Host '  ✓ Cliente finalizado (código de saída: ' \$process.ExitCode ')'
  }
"

# Remover create_data_zip.lua da pasta de trabalho (não deve ir para o release)
rm -f "$WORK_DIR/create_data_zip.lua" 2>/dev/null || true
echo "  ✓ create_data_zip.lua removido da pasta de trabalho"

# Restaurar init.lua original (o data.zip já foi criado com o init.lua original via backup)
if [[ -f "$WORK_DIR/init.lua.backup" ]]; then
  mv "$WORK_DIR/init.lua.backup" "$WORK_DIR/init.lua"
  echo "  ✓ init.lua original restaurado"
fi

# Verificar se o data.zip foi criado no AppData
# O cliente salva em: C:\Users\tiago\AppData\Roaming\OTClientV8\Calabresot\data.zip
echo "  🔍 Procurando data.zip no AppData..."
APPDATA_DIR_WIN=$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('ApplicationData') + '\\OTClientV8\\Calabresot'")
APPDATA_DIR=$(cygpath -u "$APPDATA_DIR_WIN" 2>/dev/null || echo "")

# Lista de caminhos alternativos para procurar
# Usar variáveis com fallback para evitar erro de variável não definida
USER_NAME="${USER:-${USERNAME:-$(whoami 2>/dev/null || echo "")}}"
APPDATA_PATHS=(
  "$HOME/AppData/Roaming/OTClientV8/Calabresot"
)
# Adicionar caminho com nome de usuário apenas se USER_NAME estiver definido
if [[ -n "$USER_NAME" ]]; then
  APPDATA_PATHS+=("/c/Users/$USER_NAME/AppData/Roaming/OTClientV8/Calabresot")
fi

DATA_ZIP_FOUND=false

# Tentar copiar do AppData (caminho principal)
APPDATA_SOURCE=""
if [[ -n "$APPDATA_DIR" && -f "$APPDATA_DIR/data.zip" ]]; then
  cp "$APPDATA_DIR/data.zip" "$WORK_DIR/data.zip"
  echo "  ✓ data.zip copiado de AppData: $APPDATA_DIR"
  APPDATA_SOURCE="$APPDATA_DIR"
  DATA_ZIP_FOUND=true
else
  # Tentar outros caminhos possíveis
  for APPDATA_DIR_ALT in "${APPDATA_PATHS[@]}"; do
    if [[ -f "$APPDATA_DIR_ALT/data.zip" ]]; then
      cp "$APPDATA_DIR_ALT/data.zip" "$WORK_DIR/data.zip"
      echo "  ✓ data.zip copiado de AppData: $APPDATA_DIR_ALT"
      APPDATA_SOURCE="$APPDATA_DIR_ALT"
      DATA_ZIP_FOUND=true
      break
    fi
  done
fi

# Limpar data.zip do AppData após copiar
if [[ -n "$APPDATA_SOURCE" && -f "$APPDATA_SOURCE/data.zip" ]]; then
  rm -f "$APPDATA_SOURCE/data.zip" 2>/dev/null && echo "  ✓ data.zip removido do AppData" || echo "  ⚠ Não foi possível remover data.zip do AppData (pode estar em uso)"
fi

# Se não encontrou no AppData, verificar se foi criado na pasta de trabalho
if [[ "$DATA_ZIP_FOUND" == false ]]; then
  if [[ -f "$WORK_DIR/data.zip" ]]; then
    echo "  ✓ data.zip encontrado na pasta de trabalho"
    DATA_ZIP_FOUND=true
  else
    echo "  ⚠ data.zip não encontrado. Verifique se o cliente executou corretamente."
    echo "  📍 Procurou em:"
    [[ -n "$APPDATA_DIR" ]] && echo "    - $APPDATA_DIR"
    for APPDATA_DIR_ALT in "${APPDATA_PATHS[@]}"; do
      echo "    - $APPDATA_DIR_ALT"
    done
    echo "    - $WORK_DIR"
  fi
fi

if [[ "$DATA_ZIP_FOUND" == false ]]; then
  echo "❌ Erro: data.zip não foi criado."
  rm -rf "$WORK_DIR"; exit 1
fi

echo "✅ data.zip criado com sucesso!"

# --- 4) copiar apenas executável e data.zip para pasta release ---
echo "📁 Preparando pasta release..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# executável (garante nome .exe)
FINAL_EXE_NAME="Calabreso.exe"
cp "$WORK_DIR/$EXE_PATH" "$RELEASE_DIR/$FINAL_EXE_NAME"
echo "  ✓ Executável copiado: $FINAL_EXE_NAME"

# data.zip
if [[ -f "$WORK_DIR/data.zip" ]]; then
  cp "$WORK_DIR/data.zip" "$RELEASE_DIR/"
  echo "  ✓ data.zip copiado"
else
  echo "❌ Erro: data.zip não encontrado em '$WORK_DIR'."
  rm -rf "$WORK_DIR"; exit 1
fi

echo "✅ release/ pronto (apenas executável e data.zip)."

# --- 5) limpeza: remover cópia ---
echo "🧹 Limpando cópia temporária..."
# Tentar remover arquivos de log primeiro (podem estar em uso)
rm -f "$WORK_DIR"/*.log 2>/dev/null || true
# Aguardar um pouco para garantir que arquivos foram liberados
sleep 1
# Remover o diretório (ignorar erros de arquivos em uso)
rm -rf "$WORK_DIR" 2>/dev/null || {
  echo "  ⚠ Alguns arquivos não puderam ser removidos (podem estar em uso)"
  echo "  📁 Você pode remover manualmente: $(cygpath -w "$WORK_DIR")"
}

# --- resumo ---
echo ""
echo "🎉 Build concluído!"
echo "📂 Mantidos na raiz:"
echo " - $(cygpath -w "$CLIENT_DIR")"
echo " - $(cygpath -w "$SCRIPT_DIR")/build-release.sh"
echo " - $(cygpath -w "$RELEASE_DIR")"
echo ""
echo "📦 Conteúdo de release/:"
ls -la "$RELEASE_DIR"
