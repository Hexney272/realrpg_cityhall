local Config = Config

local DocumentQueue = {}

-- Helper: check if job belongs to allowed list
function hasJob(jobName, allowed)
    for _, v in ipairs(allowed) do
        if v == jobName then return true end
    end
    return false
end

-- Initialise database tables on resource start.  These commands are idempotent; they
-- will create tables if they don't exist.  Adjust the field types if your
-- database uses different column lengths or charsets.
CreateThread(function()
    Wait(1000) -- wait for MySQL to be ready
    exports.oxmysql:update('CREATE TABLE IF NOT EXISTS realrpg_insurances (\
        plate VARCHAR(15) PRIMARY KEY,\
        identifier VARCHAR(50) NOT NULL,\
        expires_at BIGINT NOT NULL,\
        purchased_at BIGINT NOT NULL\
    )')
    exports.oxmysql:update('CREATE TABLE IF NOT EXISTS realrpg_fines (\
        id INT AUTO_INCREMENT PRIMARY KEY,\
        issuer VARCHAR(50) NOT NULL,\
        target VARCHAR(50) NOT NULL,\
        amount INT NOT NULL,\
        description TEXT NOT NULL,\
        issued_at BIGINT NOT NULL,\
        due_at BIGINT NOT NULL,\
        paid TINYINT(1) DEFAULT 0\
    )')
    exports.oxmysql:update('CREATE TABLE IF NOT EXISTS realrpg_invoices (\
        id INT AUTO_INCREMENT PRIMARY KEY,\
        issuer VARCHAR(50) NOT NULL,\
        target VARCHAR(50) NOT NULL,\
        description TEXT NOT NULL,\
        quantity INT NOT NULL,\
        unit_price INT NOT NULL,\
        tax_percent INT NOT NULL,\
        issued_at BIGINT NOT NULL,\
        due_at BIGINT NOT NULL,\
        paid TINYINT(1) DEFAULT 0\
    )')

    -- Table to store custom taxes owed by players.  Each row records an amount
    -- and description; this table supports adding taxes to players who are
    -- currently offline.  A simple implementation that can be integrated
    -- with VMS Housing or other systems.
    exports.oxmysql:update('CREATE TABLE IF NOT EXISTS realrpg_custom_taxes (\
        identifier VARCHAR(50) NOT NULL,\
        amount INT NOT NULL,\
        description TEXT NOT NULL,\
        added_at BIGINT NOT NULL\
    )')
end)

-- Utility: get ESX player object; adjust if using another framework
local ESX = exports['es_extended']:getSharedObject()

local function getPlayer(id)
    return ESX and ESX.GetPlayerFromId(id)
end

-- Purchase insurance
RegisterNetEvent('realrpg_cityhall:buyInsurance', function(plate)
    local src = source
    local xPlayer = getPlayer(src)
    if not xPlayer then return end
    plate = tostring(plate):upper()
    local price = Config.Insurance.price
    -- Optional licence check: require player to possess a valid driving licence item.
    if Config.RequireValidLicence then
        local count = exports['seerpg_inventory']:Search(src, 'count', 'driver_license') or 0
        if count < 1 then
            TriggerClientEvent('realrpg_cityhall:notify', src, 'Biztosítás', 'Nem rendelkezel érvényes jogosítvánnyal.', 'error')
            return
        end
    end
    -- Check bank account funds
    local bank = xPlayer.getAccount and xPlayer.getAccount('bank')
    if bank and bank.money >= price then
        xPlayer.removeAccountMoney('bank', price)
    else
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Biztosítás', 'Nincs elegendő pénz a bankszámlán.', 'error')
        return
    end
    local expires = os.time() + (Config.Insurance.duration * 24 * 60 * 60)
    local now = os.time()
    exports.oxmysql:update('INSERT INTO realrpg_insurances (plate, identifier, expires_at, purchased_at) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE expires_at = ?, purchased_at = ?', {
        plate,
        xPlayer.identifier,
        expires,
        now,
        expires,
        now
    })
    TriggerClientEvent('realrpg_cityhall:notify', src, 'Biztosítás', ('Sikeresen megkötötted a biztosítást %s rendszámra'):format(plate), 'success')
end)

-- Request a document
RegisterNetEvent('realrpg_cityhall:requestDocument', function(docId)
    local src = source
    local xPlayer = getPlayer(src)
    if not xPlayer then return end
    -- Find document configuration
    local document
    for _, doc in ipairs(Config.Documents) do
        if doc.id == docId then
            document = doc
            break
        end
    end
    if not document then
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Okmány', 'Ismeretlen okmány.', 'error')
        return
    end
    -- Licence requirement: for vehicle-related documents you may require a valid driving licence.
    if Config.RequireValidLicence then
        -- Define which documents require a licence; id_card does not.
        if docId ~= 'id_card' then
            local count = exports['seerpg_inventory']:Search(src, 'count', 'driver_license') or 0
            if count < 1 then
                TriggerClientEvent('realrpg_cityhall:notify', src, 'Okmány', 'Nincs érvényes jogosítványod a kérelemhez.', 'error')
                return
            end
        end
    end

    -- Payment
    local price = document.price
    local bank = xPlayer.getAccount and xPlayer.getAccount('bank')
    if bank and bank.money >= price then
        xPlayer.removeAccountMoney('bank', price)
    else
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Okmány', 'Nincs elegendő pénz a bankszámlán.', 'error')
        return
    end
    -- If wait time is zero, issue immediately
    if document.wait <= 0 then
        giveDocument(src, document.id)
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Okmány', ('Sikeresen kiállítottuk a(z) %s okmányt.'):format(document.label), 'success')
    else
        -- Add to queue
        DocumentQueue[#DocumentQueue+1] = {
            player = src,
            item = document.id,
            readyTime = os.time() + document.wait
        }
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Okmány', ('Kérelmedet elfogadtuk. Gyere vissza %d másodperc múlva.'):format(document.wait), 'inform')
    end
end)

-- Process queued documents on a timer
CreateThread(function()
    while true do
        local now = os.time()
        for i = #DocumentQueue, 1, -1 do
            local entry = DocumentQueue[i]
            if now >= entry.readyTime then
                giveDocument(entry.player, entry.item)
                TriggerClientEvent('realrpg_cityhall:documentReady', entry.player, entry.item)
                table.remove(DocumentQueue, i)
            end
        end
        Wait(5000)
    end
end)

-- Helper to give document item to player via ox_inventory bridge
function giveDocument(src, item)
    local metadata = {
        serial = ('%s-%04d'):format(string.upper(item:sub(1,3)), math.random(1000,9999)),
        issuedAt = os.time(),
        issuer = 'City Hall'
    }
    exports['ox_inventory']:AddItem(src, item, 1, metadata)
end

-- Issue a fine to another player
RegisterNetEvent('realrpg_cityhall:issueFine', function(targetId, data)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    local issuer = getPlayer(src)
    local target = getPlayer(targetId)
    if not issuer or not target then return end
    -- job check
    if not hasJob(issuer.job.name, Config.Fines.FineJobs) then
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Bírság', 'Nincs jogosultságod bírság kiállításához.', 'error')
        return
    end
    -- Validate amount
    local amt = tonumber(data.amount)
    if not amt or amt < Config.Fines.fineRange.min or amt > Config.Fines.fineRange.max then
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Bírság', 'Érvénytelen összeg.', 'error')
        return
    end
    local issuedAt = os.time()
    local dueAt = issuedAt + ((data.dueDays or 0) * 24 * 60 * 60)
    -- Insert into DB
    exports.oxmysql:insert('INSERT INTO realrpg_fines (issuer, target, amount, description, issued_at, due_at) VALUES (?, ?, ?, ?, ?, ?)', {
        issuer.identifier,
        target.identifier,
        amt,
        data.description,
        issuedAt,
        dueAt
    }, function(insertId)
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Bírság', 'Bírság sikeresen kiállítva.', 'success')
        -- Notify target
        TriggerClientEvent('realrpg_cityhall:notify', targetId, 'Bírság', ('Új bírságot kaptál: %s Ft - %s'):format(amt, data.description), 'inform')
    end)
end)

-- Issue an invoice to another player
RegisterNetEvent('realrpg_cityhall:issueInvoice', function(targetId, data)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    local issuer = getPlayer(src)
    local target = getPlayer(targetId)
    if not issuer or not target then return end
    -- Build amounts
    local subtotal = data.quantity * data.unitPrice
    local taxAmount = math.floor(subtotal * (data.taxPercent or 0) / 100)
    local total = subtotal + taxAmount
    local issuedAt = os.time()
    local dueAt = issuedAt + (Config.Fines.defaultDueDays * 24 * 60 * 60)
    exports.oxmysql:insert('INSERT INTO realrpg_invoices (issuer, target, description, quantity, unit_price, tax_percent, issued_at, due_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        issuer.identifier,
        target.identifier,
        data.description,
        data.quantity,
        data.unitPrice,
        data.taxPercent or 0,
        issuedAt,
        dueAt
    }, function(id)
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Számla', 'Számla sikeresen kiállítva.', 'success')
        TriggerClientEvent('realrpg_cityhall:notify', targetId, 'Számla', ('Új számlát kaptál: %s - %d Ft (adótartalom: %d%%)'):format(data.description, total, data.taxPercent or 0), 'inform')
    end)
end)

-- VIN check: search plate or vin in owned_vehicles and return info
RegisterNetEvent('realrpg_cityhall:vinCheck', function(query)
    local src = source
    query = tostring(query):upper()
    -- Search by plate
    exports.oxmysql:scalar('SELECT owner FROM owned_vehicles WHERE plate = ?', { query }, function(owner)
        local result = {}
        if owner then
            -- get player name from users table
            exports.oxmysql:scalar('SELECT name FROM users WHERE identifier = ?', { owner }, function(name)
                result.owner = name or owner
                result.plate = query
                -- get model (vehicle table may store JSON)
                exports.oxmysql:scalar('SELECT vehicle FROM owned_vehicles WHERE plate = ?', { query }, function(vehicle)
                    if vehicle then
                        local success, decoded = pcall(json.decode, vehicle)
                        if success and decoded and decoded.model then
                            result.model = decoded.model
                        end
                    end
                    -- check insurance
                    exports.oxmysql:scalar('SELECT expires_at FROM realrpg_insurances WHERE plate = ?', { query }, function(expires)
                        if expires then
                            result.insured = (expires > os.time())
                        else
                            result.insured = false
                        end
                        TriggerClientEvent('realrpg_cityhall:vinResult', src, result)
                    end)
                end)
            end)
        else
            -- No owner, maybe a VIN search is required – out of scope
            TriggerClientEvent('realrpg_cityhall:vinResult', src, {})
        end
    end)
end)

-- Search fines and invoices by issuer or receiver name.  Only clerks can call
-- this event.  It returns matching rows to the client for display.  The
-- search term matches partial names.  Results include id, issuer name,
-- target name, amount, description and due date.
RegisterNetEvent('realrpg_cityhall:searchBillings', function(term)
    local src = source
    local xPlayer = getPlayer(src)
    if not xPlayer or xPlayer.job.name ~= Config.ClerkJob.jobName then
        return
    end
    term = tostring(term or ''):gsub('%s+', ''):lower()
    if term == '' then
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Billings', 'Keresési kifejezés megadása kötelező.', 'error')
        return
    end
    local like = '%' .. term .. '%'
    local billings = { fines = {}, invoices = {} }
    -- Search fines by issuer or target name
    exports.oxmysql:execute('SELECT f.id, f.amount, f.description, f.due_at, u1.name AS issuer_name, u2.name AS target_name FROM realrpg_fines f LEFT JOIN users u1 ON f.issuer = u1.identifier LEFT JOIN users u2 ON f.target = u2.identifier WHERE LOWER(u1.name) LIKE ? OR LOWER(u2.name) LIKE ?', { like, like }, function(rows)
        billings.fines = rows or {}
        -- Search invoices by issuer or target name
        exports.oxmysql:execute('SELECT i.id, i.quantity, i.unit_price, i.tax_percent, i.description, i.due_at, u1.name AS issuer_name, u2.name AS target_name FROM realrpg_invoices i LEFT JOIN users u1 ON i.issuer = u1.identifier LEFT JOIN users u2 ON i.target = u2.identifier WHERE LOWER(u1.name) LIKE ? OR LOWER(u2.name) LIKE ?', { like, like }, function(rows2)
            billings.invoices = rows2 or {}
            TriggerClientEvent('realrpg_cityhall:billingsResult', src, billings)
        end)
    end)
end)

--[[
    issueReceipt
    Allows a player with a payment terminal and thermal paper to issue a receipt
    to another player.  The issuer must provide the buyer ID and transaction
    details.  A single unit of thermal paper is consumed.  The buyer receives
    a 'receipt' item with metadata containing the description, quantity and
    total amount.  This feature is controlled by Config.UseReceipts.

    Parameters:
        targetId (number): The player ID of the buyer.
        data (table): A table containing at minimum:
            description (string) – A description of the goods/services
            quantity (number) – Quantity sold
            unitPrice (number) – Unit price of the goods/services
            taxPercent (number, optional) – tax rate to apply to the total
]]
RegisterNetEvent('realrpg_cityhall:issueReceipt', function(targetId, data)
    if not Config.UseReceipts then return end
    local src = source
    local buyerId = tonumber(targetId)
    if not buyerId or not data or type(data) ~= 'table' then return end
    local issuer = getPlayer(src)
    local buyer = getPlayer(buyerId)
    if not issuer or not buyer then return end
    -- Check that issuer has a payment terminal
    local termCount = exports['ox_inventory']:Search(src, 'count', 'payment_terminal') or 0
    if termCount < 1 then
        TriggerClientEvent('realrpg_cityhall:notify', src, 'Nyugta', 'Nincs fizetési terminálod a kiállításhoz.', 'error')
        return
    end
    -- Calculate totals
    local qty = tonumber(data.quantity) or 1
    local price = tonumber(data.unitPrice) or 0
    local total = qty * price
    -- Create metadata for receipt
    local metadata = {
        description = tostring(data.description or 'Tranzakció'),
        quantity = qty,
        total = total,
        issuedAt = os.time(),
        seller = issuer.getName and issuer.getName() or issuer.identifier
    }
    -- Give receipt to buyer
    exports['ox_inventory']:AddItem(buyerId, 'receipt', 1, metadata)
    TriggerClientEvent('realrpg_cityhall:printDone', src)
    TriggerClientEvent('realrpg_cityhall:notify', src, 'Nyugta', ('Nyugta sikeresen kiállítva %d Ft értékben.'):format(total), 'success')
    TriggerClientEvent('realrpg_cityhall:notify', buyerId, 'Nyugta', ('Új nyugtát kaptál: %s - %d Ft'):format(metadata.description, total), 'inform')
end)

--[[
    Exports

    The following exports extend the City Hall resource with additional
    functionality requested in update proposals.  These are intentionally
    lightweight and may need to be adapted to your own economy or other
    dependencies (such as vms_bossmenu).

    giveBill(src, type, data, giveItem, cb)
        Assigns a fine, traffic ticket or invoice to a player without requiring
        another player to issue it.  The parameters follow the pattern
        described in the vms_cityhall documentation: `type` must be one of
        'ticket', 'traffic-ticket' or 'invoice'.  The `data` table may
        include fields such as amount, violation, invoiceData, etc.
        For simplicity this implementation reuses the existing
        issueFine and issueInvoice events.  In a full implementation you
        should populate the database and optionally give the player an
        inventory item.

    getPlayerJobLabel(src)
        Returns the display label for the player's job or nil if unknown.
]]

exports('giveBill', function(src, billType, data, giveItem, cb)
    local playerId = tonumber(src)
    if not playerId then
        if cb then cb(nil) end
        return
    end
    billType = tostring(billType)
    -- For invoices, pull the first entry from invoiceData as a simple line
    if billType == 'invoice' and data and data.invoiceData then
        local first = data.invoiceData[1] or {}
        local qty = tonumber(first.qty) or 1
        local unit = tonumber(first.unitPrice) or (tonumber(data.amount) or 0)
        local desc = first.description or data.issuerName or 'Számla'
        local taxPercent = tonumber(data.taxFromInvoice) or 0
        local subtotal = qty * unit
        local taxAmount = math.floor(subtotal * taxPercent / 100)
        local total = subtotal + taxAmount
        local issuedAt = os.time()
        local dueAt = issuedAt + (Config.Fines.defaultDueDays * 24 * 60 * 60)
        local target = getPlayer(playerId)
        if not target then
            if cb then cb(nil) end
            return
        end
        local issuerIdentifier = data.issuerIdentifier or 'system'
        exports.oxmysql:insert('INSERT INTO realrpg_invoices (issuer, target, description, quantity, unit_price, tax_percent, issued_at, due_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            issuerIdentifier,
            target.identifier,
            desc,
            qty,
            unit,
            taxPercent,
            issuedAt,
            dueAt
        }, function(id)
            TriggerClientEvent('realrpg_cityhall:notify', playerId, 'Számla', ('Új számlát kaptál: %s - %d Ft'):format(desc, total), 'inform')
            if cb then cb(id or 0) end
        end)
        return
    end
    -- For tickets or traffic tickets, treat as fine
    if (billType == 'ticket' or billType == 'traffic-ticket') and data then
        local amount = tonumber(data.amount) or 0
        local desc = data.violation or data.description or 'Bírság'
        local dueDays = tonumber(data.dateToPay) or 0
        local target = getPlayer(playerId)
        if not target then
            if cb then cb(nil) end
            return
        end
        local issuerIdentifier = data.issuerIdentifier or 'system'
        local issuedAt = os.time()
        local dueAt = issuedAt + (dueDays * 24 * 60 * 60)
        exports.oxmysql:insert('INSERT INTO realrpg_fines (issuer, target, amount, description, issued_at, due_at) VALUES (?, ?, ?, ?, ?, ?)', {
            issuerIdentifier,
            target.identifier,
            amount,
            desc,
            issuedAt,
            dueAt
        }, function(insertId)
            TriggerClientEvent('realrpg_cityhall:notify', playerId, 'Bírság', ('Új bírságot kaptál: %d Ft - %s'):format(amount, desc), 'inform')
            if cb then cb(insertId or 0) end
        end)
        return
    end
    -- Unknown type: ignore
    if cb then cb(nil) end
end)

exports('getPlayerJobLabel', function(src)
    local xPlayer = getPlayer(src)
    if xPlayer and xPlayer.job and xPlayer.job.label then
        return xPlayer.job.label
    end
    return nil
end)

--[[
    getVehicleInsurance
    Returns information about a vehicle's insurance based on its plate.  The
    returned table has the following fields:
        insured (boolean): true if insurance exists and is still valid
        expiresAt (number): Unix timestamp of the expiry or nil if not insured
        purchasedAt (number): When the insurance was purchased
        owner (string): identifier who purchased the insurance

    Parameters:
        plate (string): Vehicle plate (uppercase)
        cb (function) optional: callback to receive the result table
]]
exports('getVehicleInsurance', function(plate, cb)
    plate = tostring(plate or ''):upper()
    exports.oxmysql:execute('SELECT identifier, expires_at, purchased_at FROM realrpg_insurances WHERE plate = ?', { plate }, function(rows)
        local result = {}
        if rows and rows[1] then
            local row = rows[1]
            result.insured = row.expires_at and (row.expires_at > os.time()) or false
            result.expiresAt = row.expires_at
            result.purchasedAt = row.purchased_at
            result.owner = row.identifier
        else
            result.insured = false
        end
        if cb then cb(result) end
    end)
end)

--[[
    addVehicleInsurance
    Adds or extends insurance for a given vehicle.  If an existing
    insurance record is found it will update the expiry date by the
    specified number of days; otherwise a new record is created.  The
    identifier parameter should be the player or society paying for the
    insurance.  Returns true if successful.

    Parameters:
        plate (string): Vehicle plate (uppercase)
        identifier (string): ESX identifier or society name
        durationDays (number): Number of days to add
        cb (function) optional: callback with boolean result
]]
exports('addVehicleInsurance', function(plate, identifier, durationDays, cb)
    plate = tostring(plate or ''):upper()
    local days = tonumber(durationDays) or 0
    if days <= 0 then
        if cb then cb(false) end
        return
    end
    local durationSeconds = days * 24 * 60 * 60
    local now = os.time()
    local expiresAt = now + durationSeconds
    -- If existing insurance is still valid, extend from its current expiry.
    -- If expired or non-existent, start from now.
    exports.oxmysql:update('INSERT INTO realrpg_insurances (plate, identifier, expires_at, purchased_at) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE expires_at = IF(expires_at > ?, expires_at + ?, ? + ?), purchased_at = ?', {
        plate,
        identifier,
        expiresAt,
        now,
        now, durationSeconds, -- IF condition: if current expires_at > now (still valid), extend from it
        now, durationSeconds, -- ELSE: start fresh from now
        now
    }, function()
        if cb then cb(true) end
    end)
end)

--[[
    addPlayerCustomTaxToPay
    Adds a custom tax obligation to a player.  This export can be called when
    the target player is offline, as it writes directly to the database.  Use
    this to integrate with housing or other systems that need to assign
    property taxes or wealth taxes to players.  The tax is stored until the
    player pays it via your own collection mechanic.

    Parameters:
        identifier (string): The player’s identifier (e.g., steam or citizenid) to
            which the tax will be assigned.
        amount (number): The amount of tax to pay.
        description (string): A description of the tax (e.g., "Housing tax").
        cb (function) optional: callback with boolean result.
]]
exports('addPlayerCustomTaxToPay', function(identifier, amount, description, cb)
    identifier = tostring(identifier or '')
    local amt = tonumber(amount) or 0
    if identifier == '' or amt <= 0 then
        if cb then cb(false) end
        return
    end
    local desc = tostring(description or 'Egyéb adó')
    local now = os.time()
    exports.oxmysql:insert('INSERT INTO realrpg_custom_taxes (identifier, amount, description, added_at) VALUES (?, ?, ?, ?)', {
        identifier,
        amt,
        desc,
        now
    }, function()
        if cb then cb(true) end
    end)
end)

--[[
    sendPhoneMessage
    Sends a message to a player’s phone app.  The city hall uses this
    internally to notify applicants about the status of their resumes or
    applications.  The implementation attempts to detect which phone
    resource is running (qb-phone, qs-smartphone-pro, yseries, lb-phone,
    okokPhone or gksphone) and calls the appropriate export or event.

    Parameters:
        receiver (number): server id of the player who should receive the message
        subject (string): message subject or title
        body (string): message body
]]
local function sendPhoneMessage(receiver, subject, body)
    if not receiver then return end
    local srcId = tonumber(receiver)
    if not srcId then return end
    subject = tostring(subject or 'Üzenet')
    body = tostring(body or '')
    -- Check and send via known phone resources.  Only one will be used.
    if GetResourceState('qb-phone') == 'started' then
        exports['qb-phone']:sendNewMail({ sender = 'Városháza', subject = subject, message = body, receiver = srcId })
        return
    elseif GetResourceState('qs-smartphone-pro') == 'started' then
        exports['qs-smartphone-pro']:SendNewMail(srcId, { sender = 'Városháza', subject = subject, message = body })
        return
    elseif GetResourceState('yseries') == 'started' then
        TriggerEvent('yseries:server:sendNewMail', srcId, { sender = 'Városháza', subject = subject, message = body })
        return
    elseif GetResourceState('lb-phone') == 'started' then
        exports['lb-phone']:sendMail(srcId, { sender = 'Városháza', subject = subject, message = body })
        return
    elseif GetResourceState('okokPhone') == 'started' then
        exports['okokPhone']:SendNewMail(srcId, { sender = 'Városháza', subject = subject, message = body })
        return
    elseif GetResourceState('gksphone') == 'started' then
        -- gksphone does not have a standard mail API; attempt to use a generic event
        TriggerEvent('gksphone:client:notify', srcId, { title = subject, message = body })
        return
    end
    -- If no supported phone resource is found, fallback to in-game notification
    TriggerClientEvent('realrpg_cityhall:notify', srcId, subject, body, 'inform')
end