local RESOURCE = GetCurrentResourceName()
local PHONE_RESOURCE = 'forge-npwd'
local purchaseLocks = {}

local function response(success, errorCode, extra)
    local payload = extra or {}
    payload.success = success == true
    payload.error = errorCode
    return payload
end

local function getModel(modelId)
    for _, model in ipairs(Config.Models or {}) do
        if model.id == modelId then return model end
    end
end

local function getColor(model, colorId)
    for _, color in ipairs(model and model.colors or {}) do
        if color.id == colorId then return color end
    end
end

local function awaitPhoneExport(exportName, ...)
    if GetResourceState(PHONE_RESOURCE) ~= 'started' then
        return response(false, 'PHONE_RESOURCE_UNAVAILABLE')
    end

    local deferred = promise.new()
    local settled = false
    local args = { ... }
    args[#args + 1] = function(result)
        if settled then return end
        settled = true
        deferred:resolve(result)
    end

    local ok, err = pcall(function()
        -- Dynamic FiveM export calls need the neutral proxy argument first.
        -- Without it, every argument is shifted and the callback is never delivered.
        exports[PHONE_RESOURCE][exportName](nil, table.unpack(args))
    end)
    if not ok then
        print(('[Forge NPWD Shop] Export %s failed: %s'):format(exportName, tostring(err)))
        return response(false, 'PHONE_EXPORT_FAILED', { detail = tostring(err) })
    end

    SetTimeout(Config.PhoneExportTimeout or 15000, function()
        if settled then return end
        settled = true
        print(('[Forge NPWD Shop] Export %s timed out after %sms'):format(
            exportName,
            Config.PhoneExportTimeout or 15000
        ))
        deferred:resolve(response(false, 'PHONE_EXPORT_TIMEOUT'))
    end)

    return Citizen.Await(deferred)
end

local function takePayment(source, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return 'free' end

    for _, account in ipairs(Config.PaymentAccounts or { 'cash', 'bank' }) do
        local balance = tonumber(pr_lib.framework.getPlayerMoney(source, account)) or 0
        if balance >= amount and pr_lib.framework.removePlayerMoney(
            source,
            account,
            amount,
            ('%s purchase'):format(RESOURCE)
        ) == true then
            return account
        end
    end

    return nil
end

local function refundPayment(source, account, amount)
    if not account or account == 'free' or amount <= 0 then return end
    pr_lib.framework.addPlayerMoney(source, account, amount, ('%s refund'):format(RESOURCE))
end

local function acquireLock(source)
    if purchaseLocks[source] then return false end
    purchaseLocks[source] = true
    return true
end

local function finishOperation(source, result)
    purchaseLocks[source] = nil
    return result
end

AddEventHandler('playerDropped', function()
    purchaseLocks[source] = nil
end)

pr_lib.callback.register('forge-npwd-shop:server:getDevices', function(source)
    if not pr_lib.framework.GetPlayer(source) then
        return response(false, 'PLAYER_NOT_LOADED', { devices = {} })
    end
    local devices = awaitPhoneExport('getOwnedPhoneDevices', source)
    if type(devices) ~= 'table' or devices.success == false then
        local result = type(devices) == 'table' and devices or response(false, 'PHONE_EXPORT_FAILED')
        result.devices = {}
        return result
    end
    return response(true, nil, { devices = devices })
end)

pr_lib.callback.register('forge-npwd-shop:server:buyPhone', function(source, modelId, colorId)
    if not pr_lib.framework.GetPlayer(source) then return response(false, 'PLAYER_NOT_LOADED') end
    if not acquireLock(source) then return response(false, 'PLEASE_WAIT') end

    local model = getModel(modelId)
    local color = getColor(model, colorId)
    if not model or not color then
        return finishOperation(source, response(false, 'INVALID_CATALOG_SELECTION'))
    end

    local price = math.max(0, math.floor(tonumber(model.price) or 0))
    local account = takePayment(source, price)
    if not account then return finishOperation(source, response(false, 'NOT_ENOUGH_MONEY')) end

    local result = awaitPhoneExport('issueNewPhone', source, model.id, color.id)
    if type(result) ~= 'table' or result.success ~= true then
        refundPayment(source, account, price)
        return finishOperation(
            source,
            type(result) == 'table' and result or response(false, 'PHONE_ISSUE_FAILED')
        )
    end

    result.model = model.id
    result.modelLabel = model.label
    result.color = color.id
    result.colorLabel = color.label
    result.price = price
    return finishOperation(source, result)
end)

pr_lib.callback.register('forge-npwd-shop:server:cancelPhone', function(source, deviceId)
    if not pr_lib.framework.GetPlayer(source) then return response(false, 'PLAYER_NOT_LOADED') end
    if not acquireLock(source) then return response(false, 'PLEASE_WAIT') end
    return finishOperation(
        source,
        awaitPhoneExport('cancelLostPhone', source, tostring(deviceId or ''))
    )
end)

pr_lib.callback.register('forge-npwd-shop:server:recoverPhone', function(source, deviceId)
    if not pr_lib.framework.GetPlayer(source) then return response(false, 'PLAYER_NOT_LOADED') end
    if not acquireLock(source) then return response(false, 'PLEASE_WAIT') end

    local price = math.max(0, math.floor(tonumber(Config.RecoveryPrice) or 0))
    local account = takePayment(source, price)
    if not account then return finishOperation(source, response(false, 'NOT_ENOUGH_MONEY')) end

    local cancelResult = awaitPhoneExport('cancelLostPhone', source, tostring(deviceId or ''))
    if type(cancelResult) ~= 'table' or cancelResult.success ~= true then
        refundPayment(source, account, price)
        return finishOperation(
            source,
            type(cancelResult) == 'table' and cancelResult or response(false, 'PHONE_CANCEL_FAILED')
        )
    end

    local result = awaitPhoneExport('issueReplacementPhone', source, tostring(deviceId or ''))
    if type(result) ~= 'table' or result.success ~= true then
        refundPayment(source, account, price)
        return finishOperation(
            source,
            type(result) == 'table' and result or response(false, 'PHONE_RECOVERY_FAILED')
        )
    end

    result.price = price
    return finishOperation(source, result)
end)

