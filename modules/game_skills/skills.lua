skillsWindow = nil
skillsButton = nil
manaLeechValue = 0
lifeLeechValue = 0
magicLevelPointsValue = 0
skillSwordValue = 0
skillAxeValue = 0
skillClubValue = 0
skillDistanceValue = 0
skillShieldValue = 0
extraReflectValue = 0
extraSpeedValue = 0
extraManaPercentValue = 0
extraHealthPercentValue = 0
absorbPercentPhysicalValue = 0
absorbPercentDeathValue = 0
absorbPercentFireValue = 0
absorbPercentEnergyValue = 0
absorbPercentEarthValue = 0

function init()
  connect(LocalPlayer, {
    onExperienceChange = onExperienceChange,
    onLevelChange = onLevelChange,
    onHealthChange = onHealthChange,
    onManaChange = onManaChange,
    onSoulChange = onSoulChange,
    onFreeCapacityChange = onFreeCapacityChange,
    onTotalCapacityChange = onTotalCapacityChange,
    onStaminaChange = onStaminaChange,
    onOfflineTrainingChange = onOfflineTrainingChange,
    onRegenerationChange = onRegenerationChange,
    onSpeedChange = onSpeedChange,
    onBaseSpeedChange = onBaseSpeedChange,
    onMagicLevelChange = onMagicLevelChange,
    onBaseMagicLevelChange = onBaseMagicLevelChange,
    onSkillChange = onSkillChange,
    onBaseSkillChange = onBaseSkillChange
  })
  connect(g_game, {
    onGameStart = refresh,
    onGameEnd = offline
  })

  skillsButton = modules.client_topmenu.addRightGameToggleButton('skillsButton', tr('Skills'),
    '/images/topbuttons/skills', toggle, false, 1)
  skillsButton:setOn(true)
  skillsWindow = g_ui.loadUI('skills', modules.game_interface.getRightPanel())

  -- Registra callback para opcode 233 (player stats)
  ProtocolGame.registerExtendedOpcode(233, onPlayerStatsOpcode)

  refresh()
  skillsWindow:setup()
end

function terminate()
  disconnect(LocalPlayer, {
    onExperienceChange = onExperienceChange,
    onLevelChange = onLevelChange,
    onHealthChange = onHealthChange,
    onManaChange = onManaChange,
    onSoulChange = onSoulChange,
    onFreeCapacityChange = onFreeCapacityChange,
    onTotalCapacityChange = onTotalCapacityChange,
    onStaminaChange = onStaminaChange,
    onOfflineTrainingChange = onOfflineTrainingChange,
    onRegenerationChange = onRegenerationChange,
    onSpeedChange = onSpeedChange,
    onBaseSpeedChange = onBaseSpeedChange,
    onMagicLevelChange = onMagicLevelChange,
    onBaseMagicLevelChange = onBaseMagicLevelChange,
    onSkillChange = onSkillChange,
    onBaseSkillChange = onBaseSkillChange
  })
  disconnect(g_game, {
    onGameStart = refresh,
    onGameEnd = offline
  })

  -- Desregistra callback do opcode 233
  ProtocolGame.unregisterExtendedOpcode(233)

  skillsWindow:destroy()
  skillsButton:destroy()
end

function expForLevel(level)
  return math.floor((50 * level * level * level) / 3 - 100 * level * level + (850 * level) / 3 - 200)
end

function expToAdvance(currentLevel, currentExp)
  return expForLevel(currentLevel + 1) - currentExp
end

function resetSkillColor(id)
  local skill = skillsWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')
  widget:setColor('#bbbbbb')
end

function toggleSkill(id, state)
  local skill = skillsWindow:recursiveGetChildById(id)
  skill:setVisible(state)
end

function setSkillBase(id, value, baseValue)
  if baseValue <= 0 or value < 0 then
    return
  end
  local skill = skillsWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')

  if value > baseValue then
    widget:setColor('#008b00') -- green
    skill:setTooltip(baseValue .. ' +' .. (value - baseValue))
  elseif value < baseValue then
    widget:setColor('#b22222') -- red
    skill:setTooltip(baseValue .. ' ' .. (value - baseValue))
  else
    widget:setColor('#bbbbbb') -- default
    skill:removeTooltip()
  end
end

function setSkillValue(id, value)
  local skill = skillsWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')
  widget:setText(value)
end

function setSkillColor(id, value)
  local skill = skillsWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')
  widget:setColor(value)
end

function setSkillTooltip(id, value)
  local skill = skillsWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')
  widget:setTooltip(value)
end

function setSkillPercent(id, percent, tooltip, color)
  local skill = skillsWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('percent')
  if widget then
    widget:setPercent(math.floor(percent))

    if tooltip then
      widget:setTooltip(tooltip)
    end

    if color then
      widget:setBackgroundColor(color)
    end
  end
end

function checkAlert(id, value, maxValue, threshold, greaterThan)
  if greaterThan == nil then greaterThan = false end
  local alert = false

  -- maxValue can be set to false to check value and threshold
  -- used for regeneration checking
  if type(maxValue) == 'boolean' then
    if maxValue then
      return
    end

    if greaterThan then
      if value > threshold then
        alert = true
      end
    else
      if value < threshold then
        alert = true
      end
    end
  elseif type(maxValue) == 'number' then
    if maxValue < 0 then
      return
    end

    local percent = math.floor((value / maxValue) * 100)
    if greaterThan then
      if percent > threshold then
        alert = true
      end
    else
      if percent < threshold then
        alert = true
      end
    end
  end

  if alert then
    setSkillColor(id, '#b22222') -- red
  else
    resetSkillColor(id)
  end
end

function update()
  local offlineTraining = skillsWindow:recursiveGetChildById('offlineTraining')
  if not g_game.getFeature(GameOfflineTrainingTime) then
    offlineTraining:hide()
  else
    offlineTraining:show()
  end

  local regenerationTime = skillsWindow:recursiveGetChildById('regenerationTime')
  if not g_game.getFeature(GamePlayerRegenerationTime) then
    regenerationTime:hide()
  else
    regenerationTime:show()
  end
end

function refresh()
  local player = g_game.getLocalPlayer()
  if not player then return end

  if expSpeedEvent then expSpeedEvent:cancel() end
  expSpeedEvent = cycleEvent(checkExpSpeed, 30 * 1000)

  onExperienceChange(player, player:getExperience())
  onLevelChange(player, player:getLevel(), player:getLevelPercent())
  onHealthChange(player, player:getHealth(), player:getMaxHealth())
  onManaChange(player, player:getMana(), player:getMaxMana())
  onSoulChange(player, player:getSoul())
  onFreeCapacityChange(player, player:getFreeCapacity())
  onStaminaChange(player, player:getStamina())
  onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
  onOfflineTrainingChange(player, player:getOfflineTrainingTime())
  onRegenerationChange(player, player:getRegenerationTime())
  onSpeedChange(player, player:getSpeed())
  onManaLeechChange()
  onLifeLeechChange()
  onMagicLevelPointsChange()
  onSkillSwordChange()
  onSkillAxeChange()
  onSkillClubChange()
  onSkillDistanceChange()
  onSkillShieldChange()
  onExtraReflectChange()
  onExtraSpeedChange()
  onExtraManaPercentChange()
  onExtraHealthPercentChange()
  onAbsorbPercentPhysicalChange()
  onAbsorbPercentDeathChange()
  onAbsorbPercentFireChange()
  onAbsorbPercentEnergyChange()
  onAbsorbPercentEarthChange()

  local hasAdditionalSkills = g_game.getFeature(GameAdditionalSkills)
  for i = Skill.Fist, Skill.ManaLeechAmount do
    onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))
    onBaseSkillChange(player, i, player:getSkillBaseLevel(i))

    if i > Skill.Fishing then
      toggleSkill('skillId' .. i, hasAdditionalSkills)
    end
  end

  update()

  local contentsPanel = skillsWindow:getChildById('contentsPanel')
  skillsWindow:setContentMinimumHeight(44)
  if hasAdditionalSkills then
    skillsWindow:setContentMaximumHeight(480)
  else
    skillsWindow:setContentMaximumHeight(390)
  end
end

function offline()
  if expSpeedEvent then
    expSpeedEvent:cancel()
    expSpeedEvent = nil
  end
end

function toggle()
  if skillsButton:isOn() then
    skillsWindow:close()
    skillsButton:setOn(false)
  else
    skillsWindow:open()
    skillsButton:setOn(true)
  end
end

function checkExpSpeed()
  local player = g_game.getLocalPlayer()
  if not player then return end

  local currentExp = player:getExperience()
  local currentTime = g_clock.seconds()
  if player.lastExps ~= nil then
    player.expSpeed = (currentExp - player.lastExps[1][1]) / (currentTime - player.lastExps[1][2])
    onLevelChange(player, player:getLevel(), player:getLevelPercent())
  else
    player.lastExps = {}
  end
  table.insert(player.lastExps, { currentExp, currentTime })
  if #player.lastExps > 30 then
    table.remove(player.lastExps, 1)
  end
end

function onMiniWindowClose()
  skillsButton:setOn(false)
end

function onSkillButtonClick(button)
  local percentBar = button:getChildById('percent')
  if percentBar then
    percentBar:setVisible(not percentBar:isVisible())
    if percentBar:isVisible() then
      button:setHeight(21)
    else
      button:setHeight(21 - 6)
    end
  end
end

function onExperienceChange(localPlayer, value)
  local postFix = ""
  if value > 1e15 then
    postFix = "B"
    value = math.floor(value / 1e9)
  elseif value > 1e12 then
    postFix = "M"
    value = math.floor(value / 1e6)
  elseif value > 1e9 then
    postFix = "K"
    value = math.floor(value / 1e3)
  end
  setSkillValue('experience', comma_value(value) .. postFix)
end

function onLevelChange(localPlayer, value, percent)
  setSkillValue('level', value)
  local text = tr('You have %s percent to go', 100 - percent) .. '\n' ..
      comma_value(expToAdvance(localPlayer:getLevel(), localPlayer:getExperience())) .. tr(' of experience left')

  if localPlayer.expSpeed ~= nil then
    local expPerHour = math.floor(localPlayer.expSpeed * 3600)
    if expPerHour > 0 then
      local nextLevelExp = expForLevel(localPlayer:getLevel() + 1)
      local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
      local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
      hoursLeft = math.floor(hoursLeft)
      text = text .. '\n' .. comma_value(expPerHour) .. ' of experience per hour'
      text = text .. '\n' .. tr('Next level in %d hours and %d minutes', hoursLeft, minutesLeft)
    end
  end

  setSkillPercent('level', percent, text)
end

function onHealthChange(localPlayer, health, maxHealth)
  setSkillValue('health', health)
  checkAlert('health', health, maxHealth, 30)
end

function onManaChange(localPlayer, mana, maxMana)
  setSkillValue('mana', mana)
  checkAlert('mana', mana, maxMana, 30)
end

function onSoulChange(localPlayer, soul)
  setSkillValue('soul', soul)
end

function onFreeCapacityChange(localPlayer, freeCapacity)
  freeCapacity = freeCapacity * 100
  setSkillValue('capacity', freeCapacity)
  checkAlert('capacity', freeCapacity, localPlayer:getTotalCapacity(), 20)
end

function onTotalCapacityChange(localPlayer, totalCapacity)
  checkAlert('capacity', localPlayer:getFreeCapacity(), totalCapacity, 20)
end

function onStaminaChange(localPlayer, stamina)
  local hours = math.floor(stamina / 60)
  local minutes = stamina % 60
  if minutes < 10 then
    minutes = '0' .. minutes
  end
  local percent = math.floor(100 * stamina / (42 * 60)) -- max is 42 hours --TODO not in all client versions

  setSkillValue('stamina', hours .. ":" .. minutes)

  local isPremiumAcc = G.characterAccount.premDays > 0

  --TODO not all client versions have premium time
  if g_game.getClientVersion() < 1038 then
    -- TEU CLIENT (800)
    if isPremiumAcc and stamina > 2340 then
      -- PREMIUM: bônus de 50% por 3 horas (42h -> 39h)
      local text = tr("You have %s hours and %s minutes left", hours, minutes) .. '\n' ..
          tr("Now you will gain 50%% more experience")
      setSkillPercent('stamina', percent, text, 'green')
    elseif (not isPremiumAcc) and stamina > 2460 then
      -- FREE: bônus de 50% só na 1ª hora (42h -> 41h)
      local text = tr("You have %s hours and %s minutes left", hours, minutes) .. '\n' ..
          tr("As a free account, you will gain 50%% more experience for 1 hour")
      setSkillPercent('stamina', percent, text, 'green')
    elseif stamina > 840 then
      -- sem bônus, mas acima de 14h
      setSkillPercent('stamina', percent,
        tr("You have %s hours and %s minutes left", hours, minutes), 'orange')
    elseif stamina > 0 then
      -- 0 < stamina <= 14h: penalidade
      local text = tr("You have %s hours and %s minutes left", hours, minutes) .. "\n" ..
          tr("You gain only 50%% experience and you don't may gain loot from monsters")
      setSkillPercent('stamina', percent, text, 'red')
    else -- stamina == 0
      local text = tr("You have %s hours and %s minutes left", hours, minutes) .. "\n" ..
          tr("You don't may receive experience and loot from monsters")
      setSkillPercent('stamina', percent, text, 'black')
    end
  else
    -- clients 1038+ (mantido pra compatibilidade, se quiser)
    if localPlayer:isPremium() and stamina > 2340 then
      local text = tr("You have %s hours and %s minutes left", hours, minutes) .. '\n' ..
          tr("Now you will gain 50%% more experience")
      setSkillPercent('stamina', percent, text, 'green')
    elseif (not localPlayer:isPremium()) and stamina > 2460 then
      local text = tr("You have %s hours and %s minutes left", hours, minutes) .. '\n' ..
          tr("As a free account, you will gain 50%% more experience for 1 hour")
      setSkillPercent('stamina', percent, text, 'green')
    elseif stamina > 840 then
      setSkillPercent('stamina', percent, tr("You have %s hours and %s minutes left", hours, minutes), 'orange')
    elseif stamina > 0 then
      local text = tr("You have %s hours and %s minutes left", hours, minutes) .. "\n" ..
          tr("You gain only 50%% experience and you don't may gain loot from monsters")
      setSkillPercent('stamina', percent, text, 'red')
    else
      local text = tr("You have %s hours and %s minutes left", hours, minutes) .. "\n" ..
          tr("You don't may receive experience and loot from monsters")
      setSkillPercent('stamina', percent, text, 'black')
    end
  end
end

function onOfflineTrainingChange(localPlayer, offlineTrainingTime)
  if not g_game.getFeature(GameOfflineTrainingTime) then
    return
  end
  local hours = math.floor(offlineTrainingTime / 60)
  local minutes = offlineTrainingTime % 60
  if minutes < 10 then
    minutes = '0' .. minutes
  end
  local percent = 100 * offlineTrainingTime / (12 * 60) -- max is 12 hours

  setSkillValue('offlineTraining', hours .. ":" .. minutes)
  setSkillPercent('offlineTraining', percent, tr('You have %s percent', percent))
end

function onRegenerationChange(localPlayer, regenerationTime)
  if not g_game.getFeature(GamePlayerRegenerationTime) or regenerationTime < 0 then
    return
  end
  local minutes = math.floor(regenerationTime / 60)
  local seconds = regenerationTime % 60
  if seconds < 10 then
    seconds = '0' .. seconds
  end

  setSkillValue('regenerationTime', minutes .. ":" .. seconds)
  checkAlert('regenerationTime', regenerationTime, false, 300)
end

function onSpeedChange(localPlayer, speed)
  setSkillValue('speed', speed)

  onBaseSpeedChange(localPlayer, localPlayer:getBaseSpeed())
end

function onBaseSpeedChange(localPlayer, baseSpeed)
  setSkillBase('speed', localPlayer:getSpeed(), baseSpeed)
end

function onManaLeechChange()
  local skill = skillsWindow:recursiveGetChildById('manaleech')
  if skill then
    if manaLeechValue > 0 then
      skill:setVisible(true)
      setSkillValue('manaleech', manaLeechValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onLifeLeechChange()
  local skill = skillsWindow:recursiveGetChildById('lifeleech')
  if skill then
    if lifeLeechValue > 0 then
      skill:setVisible(true)
      setSkillValue('lifeleech', lifeLeechValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onMagicLevelPointsChange()
  local skill = skillsWindow:recursiveGetChildById('magicLevelPoints')
  if skill then
    if magicLevelPointsValue > 0 then
      skill:setVisible(true)
      setSkillValue('magicLevelPoints', '+' .. magicLevelPointsValue)
    else
      skill:setVisible(false)
    end
  end
end

function onSkillSwordChange()
  local skill = skillsWindow:recursiveGetChildById('skillSword')
  if skill then
    if skillSwordValue > 0 then
      skill:setVisible(true)
      setSkillValue('skillSword', '+' .. skillSwordValue)
    else
      skill:setVisible(false)
    end
  end
end

function onSkillAxeChange()
  local skill = skillsWindow:recursiveGetChildById('skillAxe')
  if skill then
    if skillAxeValue > 0 then
      skill:setVisible(true)
      setSkillValue('skillAxe', '+' .. skillAxeValue)
    else
      skill:setVisible(false)
    end
  end
end

function onSkillClubChange()
  local skill = skillsWindow:recursiveGetChildById('skillClub')
  if skill then
    if skillClubValue > 0 then
      skill:setVisible(true)
      setSkillValue('skillClub', '+' .. skillClubValue)
    else
      skill:setVisible(false)
    end
  end
end

function onSkillDistanceChange()
  local skill = skillsWindow:recursiveGetChildById('skillDistance')
  if skill then
    if skillDistanceValue > 0 then
      skill:setVisible(true)
      setSkillValue('skillDistance', '+' .. skillDistanceValue)
    else
      skill:setVisible(false)
    end
  end
end

function onSkillShieldChange()
  local skill = skillsWindow:recursiveGetChildById('skillShield')
  if skill then
    if skillShieldValue > 0 then
      skill:setVisible(true)
      setSkillValue('skillShield', '+' .. skillShieldValue)
    else
      skill:setVisible(false)
    end
  end
end

function onExtraReflectChange()
  local skill = skillsWindow:recursiveGetChildById('extraReflect')
  if skill then
    if extraReflectValue > 0 then
      skill:setVisible(true)
      setSkillValue('extraReflect', extraReflectValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onExtraSpeedChange()
  local skill = skillsWindow:recursiveGetChildById('extraSpeed')
  if skill then
    if extraSpeedValue > 0 then
      skill:setVisible(true)
      setSkillValue('extraSpeed', '+' .. extraSpeedValue)
    else
      skill:setVisible(false)
    end
  end
end

function onExtraManaPercentChange()
  local skill = skillsWindow:recursiveGetChildById('extraManaPercent')
  if skill then
    if extraManaPercentValue > 0 then
      skill:setVisible(true)
      setSkillValue('extraManaPercent', extraManaPercentValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onExtraHealthPercentChange()
  local skill = skillsWindow:recursiveGetChildById('extraHealthPercent')
  if skill then
    if extraHealthPercentValue > 0 then
      skill:setVisible(true)
      setSkillValue('extraHealthPercent', extraHealthPercentValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onAbsorbPercentPhysicalChange()
  local skill = skillsWindow:recursiveGetChildById('absorbPercentPhysical')
  if skill then
    if absorbPercentPhysicalValue > 0 then
      skill:setVisible(true)
      setSkillValue('absorbPercentPhysical', absorbPercentPhysicalValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onAbsorbPercentDeathChange()
  local skill = skillsWindow:recursiveGetChildById('absorbPercentDeath')
  if skill then
    if absorbPercentDeathValue > 0 then
      skill:setVisible(true)
      setSkillValue('absorbPercentDeath', absorbPercentDeathValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onAbsorbPercentFireChange()
  local skill = skillsWindow:recursiveGetChildById('absorbPercentFire')
  if skill then
    if absorbPercentFireValue > 0 then
      skill:setVisible(true)
      setSkillValue('absorbPercentFire', absorbPercentFireValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onAbsorbPercentEnergyChange()
  local skill = skillsWindow:recursiveGetChildById('absorbPercentEnergy')
  if skill then
    if absorbPercentEnergyValue > 0 then
      skill:setVisible(true)
      setSkillValue('absorbPercentEnergy', absorbPercentEnergyValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onAbsorbPercentEarthChange()
  local skill = skillsWindow:recursiveGetChildById('absorbPercentEarth')
  if skill then
    if absorbPercentEarthValue > 0 then
      skill:setVisible(true)
      setSkillValue('absorbPercentEarth', absorbPercentEarthValue .. '%')
    else
      skill:setVisible(false)
    end
  end
end

function onPlayerStatsOpcode(protocol, opcode, buffer)
  -- Faz parse do JSON
  local json_status, json_data = pcall(function() return json.decode(buffer) end)
  if not json_status then
    return
  end

  -- Extrai o valor da chave manaLeech
  if json_data and json_data.manaLeech then
    local newValue = tonumber(json_data.manaLeech) or 0
    manaLeechValue = newValue
    onManaLeechChange()
  end

  -- Extrai o valor da chave lifeLeech
  if json_data and json_data.lifeLeech then
    local newValue = tonumber(json_data.lifeLeech) or 0
    lifeLeechValue = newValue
    onLifeLeechChange()
  end

  -- Extrai o valor da chave magicLevelPoints
  if json_data and json_data.magicLevelPoints then
    local newValue = tonumber(json_data.magicLevelPoints) or 0
    magicLevelPointsValue = newValue
    onMagicLevelPointsChange()
  end

  -- Extrai o valor da chave skillSword
  if json_data and json_data.skillSword then
    local newValue = tonumber(json_data.skillSword) or 0
    skillSwordValue = newValue
    onSkillSwordChange()
  end

  -- Extrai o valor da chave skillAxe
  if json_data and json_data.skillAxe then
    local newValue = tonumber(json_data.skillAxe) or 0
    skillAxeValue = newValue
    onSkillAxeChange()
  end

  -- Extrai o valor da chave skillClub
  if json_data and json_data.skillClub then
    local newValue = tonumber(json_data.skillClub) or 0
    skillClubValue = newValue
    onSkillClubChange()
  end

  -- Extrai o valor da chave skillDistance
  if json_data and json_data.skillDistance then
    local newValue = tonumber(json_data.skillDistance) or 0
    skillDistanceValue = newValue
    onSkillDistanceChange()
  end

  -- Extrai o valor da chave skillShield
  if json_data and json_data.skillShield then
    local newValue = tonumber(json_data.skillShield) or 0
    skillShieldValue = newValue
    onSkillShieldChange()
  end

  -- Extrai o valor da chave extraReflect
  if json_data and json_data.extraReflect then
    local newValue = tonumber(json_data.extraReflect) or 0
    extraReflectValue = newValue
    onExtraReflectChange()
  end

  -- Extrai o valor da chave extraSpeed
  if json_data and json_data.extraSpeed then
    local newValue = tonumber(json_data.extraSpeed) or 0
    extraSpeedValue = newValue
    onExtraSpeedChange()
  end

  -- Extrai o valor da chave extraManaPercent
  if json_data and json_data.extraManaPercent then
    local newValue = tonumber(json_data.extraManaPercent) or 0
    extraManaPercentValue = newValue
    onExtraManaPercentChange()
  end

  -- Extrai o valor da chave extraHealthPercent
  if json_data and json_data.extraHealthPercent then
    local newValue = tonumber(json_data.extraHealthPercent) or 0
    extraHealthPercentValue = newValue
    onExtraHealthPercentChange()
  end

  -- Extrai o valor da chave absorbPercentPhysical
  if json_data and json_data.absorbPercentPhysical then
    local newValue = tonumber(json_data.absorbPercentPhysical) or 0
    absorbPercentPhysicalValue = newValue
    onAbsorbPercentPhysicalChange()
  end

  -- Extrai o valor da chave absorbPercentDeath
  if json_data and json_data.absorbPercentDeath then
    local newValue = tonumber(json_data.absorbPercentDeath) or 0
    absorbPercentDeathValue = newValue
    onAbsorbPercentDeathChange()
  end

  -- Extrai o valor da chave absorbPercentFire
  if json_data and json_data.absorbPercentFire then
    local newValue = tonumber(json_data.absorbPercentFire) or 0
    absorbPercentFireValue = newValue
    onAbsorbPercentFireChange()
  end

  -- Extrai o valor da chave absorbPercentEnergy
  if json_data and json_data.absorbPercentEnergy then
    local newValue = tonumber(json_data.absorbPercentEnergy) or 0
    absorbPercentEnergyValue = newValue
    onAbsorbPercentEnergyChange()
  end

  -- Extrai o valor da chave absorbPercentEarth
  if json_data and json_data.absorbPercentEarth then
    local newValue = tonumber(json_data.absorbPercentEarth) or 0
    absorbPercentEarthValue = newValue
    onAbsorbPercentEarthChange()
  end
end

function onMagicLevelChange(localPlayer, magiclevel, percent)
  setSkillValue('magiclevel', magiclevel)
  setSkillPercent('magiclevel', percent, tr('You have %s percent to go', 100 - percent))

  onBaseMagicLevelChange(localPlayer, localPlayer:getBaseMagicLevel())
end

function onBaseMagicLevelChange(localPlayer, baseMagicLevel)
  setSkillBase('magiclevel', localPlayer:getMagicLevel(), baseMagicLevel)
end

function onSkillChange(localPlayer, id, level, percent)
  setSkillValue('skillId' .. id, level)
  setSkillPercent('skillId' .. id, percent, tr('You have %s percent to go', 100 - percent))

  onBaseSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))
end

function onBaseSkillChange(localPlayer, id, baseLevel)
  setSkillBase('skillId' .. id, localPlayer:getSkillLevel(id), baseLevel)
end
