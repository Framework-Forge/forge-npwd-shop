local MENU_ROOT = 'forge-npwd-shop:root'
local MENU_CATALOG = 'forge-npwd-shop:catalog'
local MENU_DEVICES = 'forge-npwd-shop:devices'
local textUiVisible = false

local errorMessages = {
    PLAYER_NOT_LOADED = 'Seu personagem ainda nao foi carregado.',
    PLEASE_WAIT = 'Aguarde um instante antes de tentar novamente.',
    INVALID_CATALOG_SELECTION = 'Modelo ou cor invalida.',
    NOT_ENOUGH_MONEY = 'Voce nao possui dinheiro suficiente.',
    INVENTORY_FULL = 'Nao ha espaco no inventario para o aparelho.',
    INVENTORY_ADD_FAILED = 'Nao foi possivel entregar o aparelho.',
    DEVICE_NOT_FOUND_OR_NOT_OWNED = 'Esse aparelho nao pertence ao seu personagem.',
    DEVICE_ALREADY_REPLACED = 'Esse aparelho ja foi substituido.',
    DEVICE_MUST_BE_BLOCKED = 'O aparelho precisa ser bloqueado antes da recuperacao.',
    PHONE_RESOURCE_UNAVAILABLE = 'O Forge NPWD esta indisponivel.',
    PHONE_EXPORT_FAILED = 'Nao foi possivel comunicar com o Forge NPWD.',
    PHONE_EXPORT_TIMEOUT = 'O Forge NPWD demorou demais para responder.',
    PHONE_ISSUE_FAILED = 'Nao foi possivel emitir o novo aparelho.',
    PHONE_CANCEL_FAILED = 'Nao foi possivel bloquear o aparelho antigo.',
    PHONE_RECOVERY_FAILED = 'Nao foi possivel concluir a recuperacao.',
    PHONE_NUMBER_GENERATION_FAILED = 'Nao foi possivel gerar um numero telefonico.',
    INTERNAL_ERROR = 'Ocorreu um erro interno.'
}

local openRootMenu
local openDevicesMenu

local function currency(value)
    local formatted = tostring(math.floor(tonumber(value) or 0))
    while true do
        local updated, count = formatted:gsub('^(-?%d+)(%d%d%d)', '%1.%2')
        formatted = updated
        if count == 0 then break end
    end
    return ('$ %s'):format(formatted)
end

local function notify(description, kind)
    pr_lib.notifications.Notify({
        title = 'Forge NPWD Store',
        description = description,
        type = kind or 'inform',
        duration = 5000
    })
end

local function resultError(result)
    local code = type(result) == 'table' and result.error or 'INTERNAL_ERROR'
    return errorMessages[code] or ('Operacao recusada: %s'):format(tostring(code))
end

local function confirm(header, content)
    return pr_lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = true,
        labels = { confirm = 'Confirmar', cancel = 'Cancelar' }
    }) == 'confirm'
end

local function buyPhone(model, color)
    if not confirm(
        ('Comprar %s'):format(model.label),
        ('Cor: %s\nValor: %s'):format(color.label, currency(model.price))
    ) then return end

    local result = pr_lib.callback.await(
        'forge-npwd-shop:server:buyPhone',
        Config.CallbackTimeout or 15000,
        model.id,
        color.id
    )
    if type(result) ~= 'table' or not result.success then
        notify(resultError(result), 'error')
        return
    end

    notify(
        ('%s %s adquirido. Numero: %s'):format(model.label, color.label, result.phoneNumber or 'N/A'),
        'success'
    )
end

local function openColorsMenu(model)
    local options = {}
    for _, color in ipairs(model.colors or {}) do
        local colorEntry = color
        options[#options + 1] = {
            title = colorEntry.label,
            description = ('Comprar por %s'):format(currency(model.price)),
            icon = 'palette-fill',
            metadata = {
                { label = 'Modelo', value = model.label },
                { label = 'Cor', value = colorEntry.label },
                { label = 'Preco', value = currency(model.price) }
            },
            onSelect = function() buyPhone(model, colorEntry) end
        }
    end

    local id = ('forge-npwd-shop:colors:%s'):format(model.id)
    pr_lib.menus.RegisterContext({
        id = id,
        title = model.label,
        menu = MENU_CATALOG,
        options = options
    })
    pr_lib.menus.ShowContext(id)
end

local function openCatalogMenu()
    local options = {}
    for _, model in ipairs(Config.Models or {}) do
        local modelEntry = model
        options[#options + 1] = {
            title = modelEntry.label,
            description = ('%s | %s'):format(modelEntry.description or '', currency(modelEntry.price)),
            icon = modelEntry.icon or 'phone',
            arrow = true,
            metadata = {
                { label = 'Preco', value = currency(modelEntry.price) },
                { label = 'Cores', value = #(modelEntry.colors or {}) }
            },
            onSelect = function() openColorsMenu(modelEntry) end
        }
    end

    pr_lib.menus.RegisterContext({
        id = MENU_CATALOG,
        title = 'Comprar aparelho',
        menu = MENU_ROOT,
        options = options
    })
    pr_lib.menus.ShowContext(MENU_CATALOG)
end

local function deviceStatus(status)
    if status == 'active' then return 'Ativo' end
    if status == 'blocked' then return 'Bloqueado' end
    if status == 'replaced' then return 'Substituido' end
    return tostring(status)
end

local function cancelDevice(device)
    if not confirm(
        'Bloquear aparelho perdido',
        ('Numero: %s\nO item antigo deixara de funcionar.'):format(device.phoneNumber)
    ) then return end

    local result = pr_lib.callback.await(
        'forge-npwd-shop:server:cancelPhone',
        Config.CallbackTimeout or 15000,
        device.deviceId
    )
    if type(result) ~= 'table' or not result.success then
        notify(resultError(result), 'error')
        return
    end
    notify('Aparelho bloqueado com sucesso.', 'success')
    openDevicesMenu()
end

local function recoverDevice(device)
    if not confirm(
        'Recuperar aparelho',
        ('Numero preservado: %s\nTaxa de recuperacao: %s'):format(
            device.phoneNumber,
            currency(Config.RecoveryPrice)
        )
    ) then return end

    local result = pr_lib.callback.await(
        'forge-npwd-shop:server:recoverPhone',
        Config.CallbackTimeout or 15000,
        device.deviceId
    )
    if type(result) ~= 'table' or not result.success then
        notify(resultError(result), 'error')
        return
    end
    notify(('Novo aparelho entregue com o numero %s.'):format(result.phoneNumber), 'success')
    openDevicesMenu()
end

local function openDeviceActions(device)
    local options = {
        {
            title = device.phoneNumber,
            description = ('Modelo: %s | Status: %s'):format(device.model, deviceStatus(device.status)),
            icon = 'sim-fill',
            readOnly = true,
            metadata = {
                { label = 'Device ID', value = device.deviceId },
                { label = 'Serial', value = device.serialNumber },
                { label = 'Cor', value = device.color }
            }
        }
    }

    if device.status == 'active' then
        options[#options + 1] = {
            title = 'Bloquear aparelho perdido',
            description = 'Cancela imediatamente o acesso pelo item antigo.',
            icon = 'lock-fill',
            colorScheme = 'red',
            onSelect = function() cancelDevice(device) end
        }
    end
    if device.status == 'active' or device.status == 'blocked' then
        options[#options + 1] = {
            title = 'Recuperar em novo aparelho',
            description = ('Preserva numero e configuracoes por %s.'):format(currency(Config.RecoveryPrice)),
            icon = 'arrow-repeat',
            colorScheme = 'green',
            onSelect = function() recoverDevice(device) end
        }
    end

    local id = ('forge-npwd-shop:device:%s'):format(device.deviceId)
    pr_lib.menus.RegisterContext({
        id = id,
        title = 'Gerenciar aparelho',
        menu = MENU_DEVICES,
        options = options
    })
    pr_lib.menus.ShowContext(id)
end

openDevicesMenu = function()
    local result = pr_lib.callback.await(
        'forge-npwd-shop:server:getDevices',
        Config.CallbackTimeout or 15000
    )
    if type(result) ~= 'table' or result.success ~= true then
        notify(resultError(result), 'error')
        return
    end

    local devices = result.devices
    local options = {}

    if type(devices) == 'table' then
        for _, device in ipairs(devices) do
            local deviceEntry = device
            options[#options + 1] = {
                title = deviceEntry.phoneNumber or 'Sem numero',
                description = ('%s | %s'):format(deviceEntry.model or 'N/A', deviceStatus(deviceEntry.status)),
                icon = deviceEntry.status == 'active' and 'phone-fill' or 'phone',
                arrow = true,
                metadata = {
                    { label = 'Serial', value = deviceEntry.serialNumber or 'N/A' },
                    { label = 'Status', value = deviceStatus(deviceEntry.status) }
                },
                onSelect = function() openDeviceActions(deviceEntry) end
            }
        end
    end

    if #options == 0 then
        options[1] = {
            title = 'Nenhum aparelho registrado',
            description = 'Compre seu primeiro Forge NPWD na loja.',
            icon = 'info-circle',
            readOnly = true
        }
    end

    pr_lib.menus.RegisterContext({
        id = MENU_DEVICES,
        title = 'Meus aparelhos',
        menu = MENU_ROOT,
        options = options
    })
    pr_lib.menus.ShowContext(MENU_DEVICES)
end

openRootMenu = function()
    pr_lib.menus.RegisterContext({
        id = MENU_ROOT,
        title = 'Forge NPWD Store',
        options = {
            {
                title = 'Comprar aparelho',
                description = 'Escolha o modelo e a cor do novo telefone.',
                icon = 'bag-plus-fill',
                arrow = true,
                onSelect = openCatalogMenu
            },
            {
                title = 'Meus aparelhos',
                description = 'Bloqueie, consulte ou recupere seus telefones.',
                icon = 'phone-fill',
                arrow = true,
                onSelect = openDevicesMenu
            }
        }
    })
    pr_lib.menus.ShowContext(MENU_ROOT)
end

pr_lib.addCommand(Config.Command or 'forgephoneshop', {
    help = 'Abrir a Forge NPWD Store'
}, openRootMenu)
exports('openShop', openRootMenu)

CreateThread(function()
    for _, location in ipairs(Config.Locations or {}) do
        if location.blip and location.blip.enabled then
            local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(blip, location.blip.sprite or 521)
            SetBlipColour(blip, location.blip.color or 47)
            SetBlipScale(blip, location.blip.scale or 0.75)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(location.label or 'Forge NPWD Store')
            EndTextCommandSetBlipName(blip)
        end
    end

    while true do
        local wait = 1000
        local nearby = false
        local coords = GetEntityCoords(PlayerPedId())

        for _, location in ipairs(Config.Locations or {}) do
            local distance = #(coords - location.coords)
            if distance <= (Config.DrawDistance or 15.0) then
                wait = 0
                if location.marker and location.marker.enabled then
                    local color = location.marker.color or { r = 255, g = 122, b = 26, a = 180 }
                    DrawMarker(
                        location.marker.type or 2,
                        location.coords.x, location.coords.y, location.coords.z + 0.2,
                        0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                        0.25, 0.25, 0.25,
                        color.r, color.g, color.b, color.a,
                        false, true, 2, false, nil, nil, false
                    )
                end

                if distance <= (Config.InteractionDistance or 2.0) then
                    nearby = true
                    if not textUiVisible then
                        pr_lib.showTextUI('[E] Abrir Forge NPWD Store')
                        textUiVisible = true
                    end
                    if IsControlJustReleased(0, 38) then openRootMenu() end
                    break
                end
            end
        end

        if not nearby and textUiVisible then
            pr_lib.hideTextUI()
            textUiVisible = false
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not textUiVisible then return end
    pr_lib.hideTextUI()
end)

