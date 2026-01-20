helpWindow = nil
helpButton = nil

function init()
    helpWindow = g_ui.displayUI('help')
    if not helpWindow then
        g_logger.error("Failed to load help window UI")
        return
    end
    helpWindow:hide()

    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    if g_game.isOnline() then
        scheduleEvent(online, 10)
    end
end

function online()
    -- Botão Help é criado pelo módulo game_shop
end

function offline()
    -- Botão permanece visível
end

function terminate()
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    -- Botão Help é destruído pelo módulo game_shop
    if helpWindow then
        helpWindow:destroy()
        helpWindow = nil
    end
end

function show()
    if not helpWindow then return end
    helpWindow:show()
    helpWindow:raise()
    helpWindow:focus()
end

function hide()
    if not helpWindow then return end
    helpWindow:hide()
end

function toggle()
    if not helpWindow then
        -- Tentar recriar a janela se não existir
        helpWindow = g_ui.displayUI('help')
        if not helpWindow then
            g_logger.error("Failed to create help window")
            return
        end
    end
    if helpWindow:isVisible() then
        hide()
    else
        show()
    end
end

function openLink(url)
    g_platform.openUrl(url)
end
