# Build e Encrypt do Cliente Calabreso

Este guia explica como criar uma versão criptografada e compactada do cliente para distribuição.

## Estrutura de Pastas Necessária

Antes de executar o build, organize os arquivos da seguinte forma:

```
Cliente para encryptar/
├── build-release.sh          ← Script de build
├── create_data_zip.lua        ← Script Lua auxiliar
└── Calabreso/                ← Pasta do cliente (não criptografado)
    ├── Calabreso.exe          ← Executável
    ├── init.lua               ← Arquivo de inicialização
    ├── data/                  ← Dados do cliente
    ├── modules/               ← Módulos do cliente
    ├── layouts/               ← Layouts do cliente
    └── mods/                  ← Mods do cliente
```

## Passo a Passo

### 1. Preparação

Certifique-se de que:
- A pasta do cliente se chama exatamente `Calabreso`
- Os arquivos `build-release.sh` e `create_data_zip.lua` estão na mesma pasta que `Calabreso/`
- O cliente não está criptografado (versão de desenvolvimento)

### 2. Executar o Build

Abra um terminal bash (Git Bash no Windows) e execute:

```bash
./build-release.sh
```

O script irá:
1. ✅ Criar uma cópia temporária do cliente
2. ✅ Criptografar todos os arquivos Lua e recursos
3. ✅ Criar o `data.zip` usando a função nativa do cliente
4. ✅ Gerar a pasta `release/` com os arquivos finais

### 3. Resultado

Após a conclusão, você terá:

```
release/
├── Calabreso.exe    ← Executável criptografado
└── data.zip         ← Arquivos do cliente criptografados e compactados
```

### 4. Deploy no Servidor

1. Copie o conteúdo da pasta `release/` para o servidor:
   ```bash
   # No servidor, dentro da pasta www/api/files/
   cp Calabreso.exe /caminho/para/www/api/files/
   cp data.zip /caminho/para/www/api/files/
   ```

2. Descompacte o `data.zip` no servidor (Ubuntu/Linux):
   ```bash
   cd /caminho/para/www/api/files/
   unzip -o data.zip -d .
   ```
   
   **Parâmetros do comando:**
   - `-o`: Sobrescreve arquivos existentes sem perguntar
   - `-d .`: Extrai na pasta atual (pode especificar outro diretório se necessário)

3. Verifique se os arquivos foram extraídos corretamente:
   ```bash
   ls -la
   # Deve mostrar: Calabreso.exe, data.zip, init.lua, data/, modules/, layouts/, mods/
   ```

## Configuração de Criptografia

O script usa uma senha forte para criptografar os arquivos do cliente:

**Senha de Criptografia:** `K7#mP9@xQ2$vL4&nR8!wT5%zY3^bN6`

Esta senha está definida no arquivo `build-release.sh` na variável `ENCRYPT_PASSWORD`. 

⚠️ **Importante:**
- Mantenha esta senha segura e não a compartilhe
- Se precisar alterar a senha, edite a variável `ENCRYPT_PASSWORD` no `build-release.sh`
- A mesma senha deve ser usada para descriptografar os arquivos no cliente
- Não altere a senha entre builds sem atualizar todos os clientes existentes

## Notas Importantes

- ⚠️ O processo de build pode levar alguns minutos dependendo do tamanho dos arquivos
- ⚠️ O cliente no `release/` está totalmente criptografado e pronto para distribuição
- ⚠️ Não modifique os arquivos em `release/` após o build
- ⚠️ Mantenha sempre uma cópia do cliente original não criptografado para futuros builds

## Solução de Problemas

**Erro: "create_data_zip.lua não encontrado"**
- Verifique se o arquivo está na mesma pasta que `build-release.sh`

**Erro: "pasta Calabreso não encontrada"**
- Verifique se o nome da pasta está exatamente como `Calabreso` (case-sensitive)

**Cliente não abre após o build**
- Certifique-se de que o `init.lua` original foi restaurado corretamente
- Verifique os logs do cliente para mais detalhes
