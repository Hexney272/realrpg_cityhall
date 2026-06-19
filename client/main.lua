local Config = Config

-- ESX shared object
local ESX = exports['es_extended']:getSharedObject()

-- State
local isCityHallOpen = false
local isReceiptOpen = false
local isTerminalOpen = false

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
            docs[#docs+1] = { id = doc.id, label = doc.label, price = doc.price, wait = doc.wait }
        end
    end
    return docs
end

-- ═══════════════════════════════════════════════════════════════════
-- VÁROSHÁZA MENÜ
-- ═══════════════════════════════════════════════════════════════════

function openCityHallUI()
    if isCityHallOpen then return end
    isCityHallOpen = true

    local perms = {
        vin = hasJob(Config.VINCheckJobs)
    }

    SendNUIMessage({
        action = 'openCityHall',
        config = {
            insurancePrice = Config.Insurance.price,
            insuranceDuration = Config.Insurance.duration,
            documents = getVisibleDocuments()
        },
        permissions = perms
    })
    SetNuiFocus(true, true)
end

function closeCityHallUI()
    if not isCityHallOpen then return end
    isCityHallOpen = false
    SetNuiFocus(false, false)
end

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

RegisterNUICallback('vinCheck', function(data, cb)
    if data.query and data.query ~= '' then
        TriggerServerEvent('realrpg_cityhall:vinCheck', data.query)
    end
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════
-- NYUGTA MEGTEKINTŐ (receipt item használatakor)
-- ═══════════════════════════════════════════════════════════════════

function openReceiptViewer(metadata)
    if isReceiptOpen then return end
    isReceiptOpen = true

    SendNUIMessage({
        action = 'openReceipt',
        metadata = metadata or {}
    })
    SetNuiFocus(true, true)
end

function closeReceiptViewer()
    if not isReceiptOpen then return end
    isReceiptOpen = false
    SetNuiFocus(false, false)
end

RegisterNUICallback('closeReceipt', function(_, cb)
    closeReceiptViewer()
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════
-- FIZETÉSI TERMINÁL NUI (payment_terminal item használatakor)
-- ═══════════════════════════════════════════════════════════════════

function openTerminalUI()
    if isTerminalOpen then return end
    isTerminalOpen = true

    SendNUIMessage({ action = 'openTerminal' })
    SetNuiFocus(true, true)
end

function closeTerminalUI()
    if not isTerminalOpen then return end
    isTerminalOpen = false
    SetNuiFocus(false, false)
end

RegisterNUICallback('closeTerminal', function(_, cb)
    closeTerminalUI()
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

-- Handle issuing of tickets from NUI
RegisterNUICallback('issueTicket', function(data, cb)
    if data and data.type and data.ticketData then
        TriggerServerEvent('realrpg_cityhall:issueTicket', data.type, data.ticketData)
    end
    cb('ok')
end)

-- Handle paying tickets from NUI
RegisterNUICallback('payTicket', function(data, cb)
    if data and data.method then
        TriggerServerEvent('realrpg_cityhall:payTicket', data.method)
    end
    cb('ok')
end)

-- Handle issuing of invoices from NUI
RegisterNUICallback('issueInvoice', function(data, cb)
    if data and data.buyer then
        -- data contains description, quantity, unitPrice, taxPercent
        TriggerServerEvent('realrpg_cityhall:issueInvoice', data.buyer, {
            description = data.description,
            quantity = data.quantity,
            unitPrice = data.unitPrice,
            taxPercent = data.taxPercent or 0
        })
    end
    cb('ok')
end)

-- Handle paying invoices from NUI
RegisterNUICallback('payInvoice', function(data, cb)
    if data and data.method then
        TriggerServerEvent('realrpg_cityhall:payInvoice', data.method)
    end
    cb('ok')
end)

-- Start note-taking animation when opening ticket UI
RegisterNUICallback('startTicketAnimation', function(data, cb)
    local ped = PlayerPedId()
    -- Use a more realistic note‑taking animation.  The
    -- CODE_HUMAN_MEDIC_TIME_OF_DEATH scenario animates the
    -- player with a clipboard and pen similar to writing a citation.
    -- The final boolean controls whether the animation includes
    -- entering/leaving transitions (true) or plays instantly (false).
    TaskStartScenarioInPlace(ped, 'CODE_HUMAN_MEDIC_TIME_OF_DEATH', 0, true)
    cb('ok')
end)

-- Stop note-taking animation
RegisterNUICallback('stopTicketAnimation', function(data, cb)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    cb('ok')
end)

-- Start signing animation when signing invoice
RegisterNUICallback('startSigning', function(data, cb)
    local ped = PlayerPedId()
    -- Play a signing animation similar to writing on paper.  We use the
    -- same scenario as for the ticket to give the impression of signing.
    TaskStartScenarioInPlace(ped, 'CODE_HUMAN_MEDIC_TIME_OF_DEATH', 0, true)
    cb('ok')
end)

-- Stop signing animation
RegisterNUICallback('stopSigning', function(data, cb)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    cb('ok')
end)

-- ==================================================================
-- ITEM USE EXPORTS
-- These exports allow inventory systems to open the Ticket and Invoice
-- interfaces directly from items.  When a police officer uses a
-- ticket book item, the corresponding UI opens and plays the
-- writing animation.  Similarly, an invoice item opens the invoice
-- creation UI.
-- ==================================================================

-- Ticket item: opens regular ticket creation UI
exports('useTicket', function(data)
    -- data.metadata may contain preset plate/model values
    local meta = data and data.metadata or {}
    SendNUIMessage({ action = 'openTicket', type = 'ticket', plate = meta.plate or '', model = meta.model or '' })
    SetNuiFocus(true, true)
end)

-- Traffic ticket item: opens traffic ticket UI (with licence fields)
exports('useTrafficTicket', function(data)
    local meta = data and data.metadata or {}
    SendNUIMessage({ action = 'openTicket', type = 'traffic-ticket', plate = meta.plate or '', model = meta.model or '' })
    SetNuiFocus(true, true)
end)

-- Invoice item: opens invoice creation UI
exports('useInvoice', function(data)
    local meta = data and data.metadata or {}
    SendNUIMessage({ action = 'openInvoice', invoiceData = meta })
    SetNuiFocus(true, true)
end)

-- Server tells us printing is done -> forward to NUI
RegisterNetEvent('realrpg_cityhall:printDone', function()
    SendNUIMessage({ action = 'printDone' })
end)

-- ═══════════════════════════════════════════════════════════════════
-- ITEM USE EXPORTS (seerpg_inventory / ox_inventory compatible)
-- Az inventory client.export = 'realrpg_cityhall.useReceipt' mezővel
-- hívja meg ezeket. A data tábla tartalmazza: name, slot, count, metadata
-- ═══════════════════════════════════════════════════════════════════

-- Receipt item: open viewer NUI when used
exports('useReceipt', function(data)
    local metadata = data.metadata or {}
    local dateStr = '-'
    if metadata.issuedAt then
        dateStr = os.date('%Y.%m.%d %H:%M', metadata.issuedAt)
    end

    openReceiptViewer({
        seller = metadata.seller or 'Ismeretlen',
        serial = metadata.serial or '-',
        date = dateStr,
        description = metadata.description or '-',
        quantity = metadata.quantity or 1,
        total = metadata.total or 0
    })
end)

-- Payment terminal item: open terminal NUI when used
exports('useTerminal', function(data)
    -- A szerver oldal ellenőrzi a hőpapírt a receipt kiállításakor.
    -- Itt csak megnyitjuk a terminál NUI-t.
    openTerminalUI()
end)

-- ═══════════════════════════════════════════════════════════════════
-- MARKER & INTERACTION (Városháza helyszín)
-- ═══════════════════════════════════════════════════════════════════

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
                if not isShowingUI and not isCityHallOpen then
                    exports.ox_lib:showTextUI('[E] Városháza', { position = 'right-center' })
                    isShowingUI = true
                end
                if IsControlJustReleased(0, 38) and not isCityHallOpen then
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

-- ═══════════════════════════════════════════════════════════════════
-- SERVER EVENTS
-- ═══════════════════════════════════════════════════════════════════

-- Notifications forwarded to NUI toast
RegisterNetEvent('realrpg_cityhall:notify', function(title, msg, nType)
    if isCityHallOpen or isTerminalOpen then
        SendNUIMessage({
            action = 'notify',
            message = (title and title ~= '') and (title .. ': ' .. msg) or msg,
            type = nType or 'inform'
        })
    else
        exports.ox_lib:notify({
            title = title,
            description = msg,
            type = nType or 'inform'
        })
    end
end)

-- Document ready
RegisterNetEvent('realrpg_cityhall:documentReady', function(item)
    SendNUIMessage({
        action = 'notify',
        message = 'Okmány elkészült: ' .. tostring(item),
        type = 'success'
    })
end)

-- VIN result
RegisterNetEvent('realrpg_cityhall:vinResult', function(info)
    if isCityHallOpen then
        SendNUIMessage({ action = 'vinResult', info = info })
    end
end)

-- Billings result (fallback)
RegisterNetEvent('realrpg_cityhall:billingsResult', function(data)
    if not data then return end
    local lines = {}
    if data.fines and #data.fines > 0 then
        for _, row in ipairs(data.fines) do
            lines[#lines+1] = ('Bírság: %d Ft - %s'):format(row.amount or 0, row.description or '')
        end
    end
    if data.invoices and #data.invoices > 0 then
        for _, row in ipairs(data.invoices) do
            local total = (row.quantity or 0) * (row.unit_price or 0)
            lines[#lines+1] = ('Számla: %d Ft - %s'):format(total, row.description or '')
        end
    end
    if #lines == 0 then lines[1] = 'Nincs találat.' end
    exports.ox_lib:notify({ title = 'Billings', description = table.concat(lines, '\n'), type = 'inform', duration = 10000 })
end)

-- Command: /billings (clerk only)
RegisterCommand('billings', function()
    if not hasJob({ Config.ClerkJob.jobName }) then
        exports.ox_lib:notify({ title = 'Billings', description = 'Nincs jogosultságod.', type = 'error' })
        return
    end
    local input = exports.ox_lib:inputDialog('Számlák keresése', {
        { type = 'input', label = 'Név (kibocsátó vagy címzett)', required = true }
    })
    if input then
        TriggerServerEvent('realrpg_cityhall:searchBillings', input[1])
    end
end)
