local Config = Config

-- cache frequently used globals
local CreateThread = CreateThread
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local DrawMarker = DrawMarker

-- ESX shared object
local ESX = exports['es_extended']:getSharedObject()

-- State
local isUIOpen = false

-- Helper to check if player has one of the specified jobs
local function hasJob(jobNames)
    if not jobNames or #jobNames == 0 then return false end
    local playerData = ESX.GetPlayerData()
    if playerData and playerData.job then
        for _, job in pairs(jobNames) do
            if playerData.job.name == job then return true end
        end
    end
    return false
end

-- Build visible documents list based on config
local function getVisibleDocuments()
    local docs = {}
    for _, doc in ipairs(Config.Documents) do
        local visible = true
        if type(doc.visible) == 'function' then
            visible = doc.visible()
        elseif type(doc.visible) == 'boolean' then
            visible = doc.visible
        end
        if visible ~= false then
            docs[#docs+1] = {
                id = doc.id,
                label = doc.label,
                price = doc.price,
                wait = doc.wait
            }
        end
    end
    return docs
end

-- Open the NUI
function openCityHallUI()
    if isUIOpen then return end
    isUIOpen = true

    -- Determine permissions
    local perms = {
        fines = hasJob(Config.Fines.FineJobs),
        vin = hasJob(Config.VINCheckJobs),
        receipt = Config.UseReceipts and hasJob(Config.Fines.FineJobs)
    }

    -- Send data to NUI
    SendNUIMessage({
        action = 'open',
        config = {
            insurancePrice = Config.Insurance.price,
            insuranceDuration = Config.Insurance.duration,
            documents = getVisibleDocuments()
        },
        permissions = perms
    })

    SetNuiFocus(true, true)
end

-- Close the NUI
function closeCityHallUI()
    if not isUIOpen then return end
    isUIOpen = false
    SetNuiFocus(false, false)
end

-- NUI Callbacks
RegisterNUICallback('closeUI', function(_, cb)
    closeCityHallUI()
    cb('ok')
end)

RegisterNUICallback('buyInsurance', function(data, cb)
    if data.plate and data.plate ~= '' then
        TriggerServerEvent('realrpg_cityhall:buyInsurance', data.plate)
    end
    cb('ok')
end)

RegisterNUICallback('requestDocument', function(data, cb)
    if data.docId and data.docId ~= '' then
        TriggerServerEvent('realrpg_cityhall:requestDocument', data.docId)
    end
    cb('ok')
end)

RegisterNUICallback('issueFine', function(data, cb)
    if data.targetId and data.description and data.amount then
        TriggerServerEvent('realrpg_cityhall:issueFine', data.targetId, {
            description = data.description,
            amount = data.amount,
            dueDays = data.dueDays or 0
        })
    end
    cb('ok')
end)

RegisterNUICallback('issueInvoice', function(data, cb)
    if data.targetId and data.description and data.unitPrice then
        TriggerServerEvent('realrpg_cityhall:issueInvoice', data.targetId, {
            description = data.description,
            quantity = data.quantity or 1,
            unitPrice = data.unitPrice,
            taxPercent = data.taxPercent or 0
        })
    end
    cb('ok')
end)

RegisterNUICallback('vinCheck', function(data, cb)
    if data.query and data.query ~= '' then
        TriggerServerEvent('realrpg_cityhall:vinCheck', data.query)
    end
    cb('ok')
end)

RegisterNUICallback('issueReceipt', function(data, cb)
    if data.targetId and data.description and data.unitPrice then
        TriggerServerEvent('realrpg_cityhall:issueReceipt', data.targetId, {
            description = data.description,
            quantity = data.quantity or 1,
            unitPrice = data.unitPrice,
            taxPercent = data.taxPercent or 0
        })
    end
    cb('ok')
end)

-- Main thread draws marker and handles interaction prompts
CreateThread(function()
    local coords = Config.CityHall.coords
    local marker = Config.CityHall.marker
    local isShowingUI = false
    while true do
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local dist = #(coords - pedCoords)
        if dist < Config.CityHall.markerDistance then
            DrawMarker(marker.type, coords.x, coords.y, coords.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.size.x, marker.size.y, marker.size.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, false, false, 2, nil, nil, false)
            if dist < Config.CityHall.interactDistance then
                if not isShowingUI and not isUIOpen then
                    exports.ox_lib:showTextUI('[E] Városháza', { position = 'right-center' })
                    isShowingUI = true
                end
                if IsControlJustReleased(0, 38) and not isUIOpen then
                    exports.ox_lib:hideTextUI()
                    isShowingUI = false
                    openCityHallUI()
                end
            else
                if isShowingUI then
                    exports.ox_lib:hideTextUI()
                    isShowingUI = false
                end
            end
            Wait(0)
        else
            if isShowingUI then
                exports.ox_lib:hideTextUI()
                isShowingUI = false
            end
            Wait(1000)
        end
    end
end)

-- Receive notifications from server and forward to NUI
RegisterNetEvent('realrpg_cityhall:notify', function(title, msg, nType)
    if isUIOpen then
        SendNUIMessage({
            action = 'notify',
            message = (title and title ~= '') and (title .. ': ' .. msg) or msg,
            type = nType or 'inform'
        })
    else
        -- Fallback to ox_lib notify when UI is closed
        exports.ox_lib:notify({
            title = title,
            description = msg,
            type = nType or 'inform'
        })
    end
end)

-- Receive document ready event
RegisterNetEvent('realrpg_cityhall:documentReady', function(item, metadata)
    if isUIOpen then
        SendNUIMessage({
            action = 'documentReady',
            item = item
        })
    else
        exports.ox_lib:notify({
            title = 'Okmány elkészült',
            description = ('Megkaptad: %s'):format(item),
            type = 'success'
        })
    end
end)

-- Receive VIN check result and forward to NUI
RegisterNetEvent('realrpg_cityhall:vinResult', function(info)
    if isUIOpen then
        SendNUIMessage({
            action = 'vinResult',
            info = info
        })
    end
end)

-- Receive search results for billings (fallback to ox_lib notify)
RegisterNetEvent('realrpg_cityhall:billingsResult', function(data)
    if not data then return end
    local lines = {}
    if data.fines and #data.fines > 0 then
        table.insert(lines, '--- Bírságok ---')
        for _, row in ipairs(data.fines) do
            local due = row.due_at and os.date('%Y.%m.%d', row.due_at) or 'N/A'
            table.insert(lines, ('ID: %s | %d Ft | %s | %s'):format(
                row.id or 'N/A', row.amount or 0, row.description or '', due
            ))
        end
    end
    if data.invoices and #data.invoices > 0 then
        table.insert(lines, '--- Számlák ---')
        for _, row in ipairs(data.invoices) do
            local total = (row.quantity or 0) * (row.unit_price or 0)
            table.insert(lines, ('ID: %s | %d Ft | %s'):format(
                row.id or 'N/A', total, row.description or ''
            ))
        end
    end
    if #lines == 0 then
        lines[1] = 'Nincs találat.'
    end
    exports.ox_lib:notify({
        title = 'Billings',
        description = table.concat(lines, '\n'),
        type = 'inform',
        duration = 15000
    })
end)

-- Command: /billings
RegisterCommand('billings', function()
    if not hasJob({ Config.ClerkJob.jobName }) then
        exports.ox_lib:notify({
            title = 'Billings',
            description = 'Nincs jogosultságod.',
            type = 'error'
        })
        return
    end
    -- Use ox_lib input for billings search (simple popup, not full NUI)
    local input = exports.ox_lib:inputDialog('Számlák keresése', {
        { type = 'input', label = 'Név (kibocsátó vagy címzett)', required = true }
    })
    if input then
        TriggerServerEvent('realrpg_cityhall:searchBillings', input[1])
    end
end)
