local Config = Config

-- cache frequently used globals
local lib = lib
local CreateThread = CreateThread
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetDistanceBetweenCoords = #(vector3(0,0,0) - vector3(0,0,0)) -- replaced later
local DrawMarker = DrawMarker
local HasJobAccess = nil

-- Helper to check if player has one of the specified jobs.  Assumes ESX
-- 1.2/Legacy or qb-core style job table with `name` field.  Feel free to
-- customise this function to suit your framework.
local function hasJob(jobNames)
    if not jobNames or #jobNames == 0 then return false end
    local playerData = exports.ox_core and exports.ox_core:getPlayer() or nil
    if playerData and playerData.job then
        for _, job in pairs(jobNames) do
            if playerData.job.name == job then return true end
        end
    end
    return false
end

-- Main thread draws marker and handles interaction prompts
CreateThread(function()
    local coords = Config.CityHall.coords
    local marker = Config.CityHall.marker
    while true do
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local dist = #(coords - pedCoords)
        if dist < Config.CityHall.markerDistance then
            DrawMarker(marker.type, coords.x, coords.y, coords.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.size.x, marker.size.y, marker.size.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, false, false, 2, nil, nil, false)
            if dist < Config.CityHall.interactDistance then
                lib.showTextUI('[E] Városháza szolgáltatások', { position = 'right-center' })
                if IsControlJustReleased(0, 38) then
                    openMainMenu()
                end
            else
                lib.hideTextUI()
            end
        else
            lib.hideTextUI()
        end
        Wait(0)
    end
end)

-- Build the main menu context
function openMainMenu()
    local options = {}

    -- Insurance purchase
    options[#options+1] = {
        title = 'Kötelező biztosítás',
        description = ('Vásárlás %d Ft áron (%d nap)'):format(Config.Insurance.price, Config.Insurance.duration),
        icon = 'list-alt',
        onSelect = function()
            local input = lib.inputDialog('Biztosítás kötés', {
                { type = 'input', label = 'Rendszám', description = 'Add meg a jármű rendszámát', required = true }
            })
            if input then
                TriggerServerEvent('realrpg_cityhall:buyInsurance', input[1])
            end
        end
    }

    -- Document ordering submenu
    options[#options+1] = {
        title = 'Okmányok',
        description = 'Igényelj vagy vedd át okmányaidat',
        icon = 'file-alt',
        onSelect = function()
            openDocumentsMenu()
        end
    }

    -- Fine/invoice menu (accessible only to jobs listed in Config.Fines.FineJobs)
    if hasJob(Config.Fines.FineJobs) then
        options[#options+1] = {
            title = 'Bírság / Számla kiállítása',
            description = 'Szabálysértési bírság vagy cég számla',
            icon = 'file-invoice-dollar',
            onSelect = function()
                openFineMenu()
            end
        }
    end

    -- VIN check menu for authorised jobs
    if hasJob(Config.VINCheckJobs) then
        options[#options+1] = {
            title = 'VIN ellenőrzés',
            description = 'Jármű / biztosítás információk lekérdezése',
            icon = 'search',
            onSelect = function()
                openVINCheckMenu()
            end
        }
    end

    -- Receipt issuance menu (for businesses using payment terminals)
    if Config.UseReceipts and hasJob(Config.Fines.FineJobs) then
        options[#options+1] = {
            title = 'Nyugta kiállítása',
            description = 'Termék vagy szolgáltatás eladásakor nyugta kiállítása',
            icon = 'receipt',
            onSelect = function()
                openReceiptMenu()
            end
        }
    end

    lib.registerContext({
        id = 'cityhall_main',
        title = 'Városháza',
        options = options
    })
    lib.showContext('cityhall_main')
end

-- Receipt issuing menu
function openReceiptMenu()
    local input = lib.inputDialog('Nyugta kiállítása', {
        { type = 'number', label = 'Vásárló ID', required = true },
        { type = 'input', label = 'Termék / szolgáltatás leírása', required = true },
        { type = 'number', label = 'Mennyiség', required = true, min = 1 },
        { type = 'number', label = 'Egységár (Ft)', required = true, min = 1 },
        { type = 'number', label = 'Adó (%)', required = false }
    })
    if input then
        local buyer = input[1]
        local desc = input[2]
        local qty = input[3]
        local price = input[4]
        local tax = input[5] or 0
        TriggerServerEvent('realrpg_cityhall:issueReceipt', buyer, {
            description = desc,
            quantity = qty,
            unitPrice = price,
            taxPercent = tax
        })
    end
end

-- Documents submenu
function openDocumentsMenu()
    local opts = {}
    for _, doc in ipairs(Config.Documents) do
        local visible = true
        if type(doc.visible) == 'function' then
            -- Support function callback to determine visibility (allows dynamic checks)
            visible = doc.visible()
        elseif type(doc.visible) == 'boolean' then
            visible = doc.visible
        end
        if visible ~= false then
            opts[#opts+1] = {
                title = doc.label,
                description = ('Ár: %d Ft | Feldolgozási idő: %s'):format(doc.price, doc.wait > 0 and (doc.wait .. 's') or 'Azonnal'),
                onSelect = function()
                    TriggerServerEvent('realrpg_cityhall:requestDocument', doc.id)
                end
            }
        end
    end
    opts[#opts+1] = { title = 'Vissza', icon = 'arrow-left', onSelect = openMainMenu }
    lib.registerContext({ id = 'cityhall_docs', title = 'Okmányok', menu = 'cityhall_main', options = opts })
    lib.showContext('cityhall_docs')
end

-- Fine/invoice menu
function openFineMenu()
    lib.registerContext({
        id = 'cityhall_fine',
        title = 'Bírság / Számla',
        menu = 'cityhall_main',
        options = {
            {
                title = 'Szabálysértési bírság',
                description = 'Kötelező mezők: Részletek, összeg, határidő',
                icon = 'gavel',
                onSelect = function()
                    local input = lib.inputDialog('Szabálysértési bírság', {
                        { type = 'number', label = 'Átadni kívánt játékos ID', description = 'A cél játékos ID-je', required = true },
                        { type = 'input', label = 'Sértés leírása', required = true },
                        { type = 'number', label = 'Összeg (Ft)', description = ('Minimum %d, maximum %d'):format(Config.Fines.fineRange.min, Config.Fines.fineRange.max), required = true, min = Config.Fines.fineRange.min, max = Config.Fines.fineRange.max },
                        { type = 'number', label = 'Fizetési határidő (nap)', description = '0 = azonnal', required = true, min = 0 }
                    })
                    if input then
                        TriggerServerEvent('realrpg_cityhall:issueFine', input[1], {
                            description = input[2],
                            amount = input[3],
                            dueDays = input[4]
                        })
                    end
                end
            },
            {
                title = 'Céges számla',
                description = 'Termék/szolgáltatás értékesítés',
                icon = 'file-invoice',
                onSelect = function()
                    local input = lib.inputDialog('Céges számla kiállítása', {
                        { type = 'number', label = 'Vásárló ID', required = true },
                        { type = 'input', label = 'Termék / szolgáltatás leírása', required = true },
                        { type = 'number', label = 'Mennyiség', required = true, min = 1 },
                        { type = 'number', label = 'Egységár (Ft)', required = true, min = 1 },
                        { type = 'number', label = 'Adó (%)', required = false }
                    })
                    if input then
                        local buyerId = input[1]
                        local itemDesc = input[2]
                        local qty = input[3]
                        local unitPrice = input[4]
                        local tax = input[5] or 0
                        TriggerServerEvent('realrpg_cityhall:issueInvoice', buyerId, {
                            description = itemDesc,
                            quantity = qty,
                            unitPrice = unitPrice,
                            taxPercent = tax
                        })
                    end
                end
            },
            { title = 'Vissza', icon = 'arrow-left', onSelect = openMainMenu }
        }
    })
    lib.showContext('cityhall_fine')
end

-- VIN check menu
function openVINCheckMenu()
    -- If target mode is enabled, attempt to detect the vehicle in front of the player
    if Config.CheckVIN and Config.CheckVIN.useOnTarget then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local forward = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
        local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z, forward.x, forward.y, forward.z, 2, ped, 0)
        local _, hit, hitPos, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
        if hit == 1 and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 2 then
            local plate = GetVehicleNumberPlateText(entityHit)
            if plate and plate ~= '' then
                TriggerServerEvent('realrpg_cityhall:vinCheck', plate)
                return
            end
        end
        lib.notify({ title = 'VIN ellenőrzés', description = 'Nincs jármű előtted. Lépj közelebb, vagy használj manuális bevitelt.', type = 'error' })
    else
        local input = lib.inputDialog('VIN lekérdezés', {
            { type = 'input', label = 'Jármű VIN vagy rendszám', description = 'Adj meg VIN számot vagy rendszámot', required = true }
        })
        if input then
            TriggerServerEvent('realrpg_cityhall:vinCheck', input[1])
        end
    end
end

-- Receive notifications from server
RegisterNetEvent('realrpg_cityhall:notify', function(title, msg, type)
    lib.notify({
        title = title,
        description = msg,
        type = type or 'inform'
    })
end)

-- Receive document ready event
RegisterNetEvent('realrpg_cityhall:documentReady', function(item, metadata)
    -- When the server notifies that a document is ready, give it to player
    lib.notify({ title = 'Okmány elkészült', description = ('Megkaptad a következőt: %s'):format(item), type = 'success' })
end)

-- Receive VIN check result
RegisterNetEvent('realrpg_cityhall:vinResult', function(info)
    -- Show information via a context menu with optional actions.
    showVINResultMenu(info)
end)

-- Display VIN search results in a context menu with optional actions.
function showVINResultMenu(info)
    local lines = {}
    if info.owner then lines[#lines+1] = ('Tulajdonos: %s'):format(info.owner) end
    if info.insured ~= nil then lines[#lines+1] = ('Biztosítás: %s'):format(info.insured and 'érvényes' or 'nincs') end
    if info.plate then lines[#lines+1] = ('Rendszám: %s'):format(info.plate) end
    if info.model then lines[#lines+1] = ('Típus: %s'):format(info.model) end
    if #lines == 0 then
        lines[1] = 'Nem található információ.'
    end
    local opts = {
        {
            title = 'Információ',
            description = table.concat(lines, '\n'),
            readOnly = true
        }
    }
    -- Allow copy of VIN/plate if enabled in config and plate exists
    if Config.CheckVIN and Config.CheckVIN.allowCopy and info.plate then
        table.insert(opts, {
            title = 'Rendszám másolása',
            description = info.plate,
            onSelect = function()
                -- Send the plate in a notification so the player can copy it.
                lib.notify({ title = 'Rendszám', description = ('%s másolva a vágólapra (chat)'):format(info.plate), type = 'inform' })
                -- Trigger a chat message with the plate for copy/paste
                TriggerEvent('chat:addMessage', { args = { info.plate } })
            end
        })
    end
    -- Allow issuing a ticket if player has fine job; opens fine menu with prefilled info
    if hasJob(Config.Fines.FineJobs) and info.plate then
        table.insert(opts, {
            title = 'Bírság kiállítása',
            description = 'Új bírság kiállítása ennek a járműnek',
            onSelect = function()
                -- Open fine dialog with plate pre-filled in description
                local dialog = lib.inputDialog('Bírság kiállítása', {
                    { type = 'number', label = 'Cél játékos ID', required = true },
                    { type = 'input', label = 'Sértés leírása', default = ('Rendszám: %s | Típus: %s'):format(info.plate or '', info.model or 'ismeretlen'), required = true },
                    { type = 'number', label = 'Összeg (Ft)', description = ('Minimum %d, maximum %d'):format(Config.Fines.fineRange.min, Config.Fines.fineRange.max), required = true, min = Config.Fines.fineRange.min, max = Config.Fines.fineRange.max },
                    { type = 'number', label = 'Fizetési határidő (nap)', description = '0 = azonnal', required = true, min = 0 }
                })
                if dialog then
                    TriggerServerEvent('realrpg_cityhall:issueFine', dialog[1], {
                        description = dialog[2],
                        amount = dialog[3],
                        dueDays = dialog[4]
                    })
                end
            end
        })
    end
    opts[#opts+1] = { title = 'Bezárás', icon = 'times', onSelect = function() end }
    lib.registerContext({ id = 'vin_result', title = 'VIN ellenőrzés', options = opts })
    lib.showContext('vin_result')
end

-- Command: /billings
-- Allows clerks to search fines and invoices by issuer or receiver name.  Only
-- players with the clerk job can execute this command.  A simple input
-- dialog prompts for a search term; the results are returned via the
-- realrpg_cityhall:billingsResult event and displayed as a notification.
RegisterCommand('billings', function()
    if not hasJob({ Config.ClerkJob.jobName }) then
        lib.notify({ title = 'Billings', description = 'Nincs jogosultságod megtekinteni a számlákat.', type = 'error' })
        return
    end
    local input = lib.inputDialog('Számlák és bírságok keresése', {
        { type = 'input', label = 'Név (adó vagy címzett)', description = 'Keresési kifejezés', required = true }
    })
    if input then
        TriggerServerEvent('realrpg_cityhall:searchBillings', input[1])
    end
end)

-- Receive search results for billings
RegisterNetEvent('realrpg_cityhall:billingsResult', function(data)
    if not data then return end
    local lines = {}
    if data.fines and #data.fines > 0 then
        table.insert(lines, '--- Bírságok ---')
        for _, row in ipairs(data.fines) do
            local due = row.due_at and os.date('%Y.%m.%d', row.due_at) or 'N/A'
            table.insert(lines, ('ID: %s | Összeg: %d Ft | Leírás: %s | Kibocsátó: %s | Címzett: %s | Határidő: %s'):format(
                row.id or 'N/A', row.amount or 0, row.description or '', row.issuer_name or 'ismeretlen', row.target_name or 'ismeretlen', due
            ))
        end
    end
    if data.invoices and #data.invoices > 0 then
        table.insert(lines, '--- Számlák ---')
        for _, row in ipairs(data.invoices) do
            local total = (row.quantity or 0) * (row.unit_price or 0)
            local due = row.due_at and os.date('%Y.%m.%d', row.due_at) or 'N/A'
            table.insert(lines, ('ID: %s | Összeg: %d Ft | Leírás: %s | Kibocsátó: %s | Címzett: %s | Határidő: %s'):format(
                row.id or 'N/A', total, row.description or '', row.issuer_name or 'ismeretlen', row.target_name or 'ismeretlen', due
            ))
        end
    end
    if #lines == 0 then
        lines[1] = 'Nincs találat.'
    end
    lib.notify({ title = 'Billings eredmények', description = table.concat(lines, '\n'), type = 'inform', duration = 15000 })
end)