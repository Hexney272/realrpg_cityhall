--- Configuration for RealRPG City Hall

---
-- The Config table defines all tunable values for the city hall script.  Adjust
-- these numbers, strings and lists to suit your economy, pricing and server
-- layout.  Coordinates are examples and should be changed to the actual city
-- hall location on your map.  Distances are in metres.
Config = {}

-- Location of the city hall marker and interaction.  When a player stands
-- within `markerDistance` metres they will see a prompt to open the menu.
Config.CityHall = {
    coords = vector3(-548.99, -203.21, 37.22), -- Example: Vespucci City Hall entrance
    heading = 65.0,
    markerDistance = 15.0,
    interactDistance = 2.5,
    marker = {
        type = 2,
        size = vec3(0.4, 0.4, 0.4),
        color = { r = 0, g = 150, b = 200, a = 150 }
    }
}

-- Document settings.  Each entry represents a document that players may order
-- or collect from the city hall.  `id` is the inventory item name, `label` is
-- what appears in menus, `price` is the cost in your server currency and
-- `wait` is the processing time in seconds.  If `wait` is 0 the document is
-- issued immediately.
Config.Documents = {
    -- id_card: Basic ID card for citizens
    { id = 'id_card', label = 'Személyi igazolvány', price = 20000, wait = 600 },
    -- vehicle_sale_agreement: Contract to sell a vehicle
    { id = 'vehicle_sale_agreement', label = 'Adásvételi szerződés', price = 5000, wait = 0 },
    -- vehicle_reregistration: Change of owner (transferring ownership)
    { id = 'vehicle_reregistration', label = 'Átírás', price = 7500, wait = 0 },
    -- plate_change: Application for changing the licence plate.  The `visible` key is
    -- controlled by the AllowToChangePlate option defined below.  If false, the
    -- document will be hidden from the menu.
    { id = 'plate_change', label = 'Rendszámcsere', price = 100000, wait = 0, visible = function() return Config.AllowToChangePlate end }
}

-- Insurance settings.  Players can purchase insurance for their vehicles.  The
-- price is a base cost that can be multiplied by additional factors (e.g. car
-- class) on the server side if desired.  `duration` defines how many days the
-- insurance remains valid from the moment of purchase.  `discountedRepair`
-- toggles whether insured vehicles receive a discount on repairs (this
-- requires integration with your mechanic script).
Config.Insurance = {
    price = 50000,
    duration = 30, -- days
    discountedRepair = true,
    repairDiscountPercent = 25 -- percent
}

-- Fines configuration.  Jobs listed in `FineJobs` can issue fines.  Each fine
-- must fall within `fineRange.min` and `fineRange.max`.  `acceptRequired`
-- toggles whether the target must accept the fine before it becomes valid.
-- `defaultDueDays` sets how many days the player has to pay the fine when
-- immediate payment is not required.
Config.Fines = {
    FineJobs = { 'police', 'sheriff', 'clerk' },
    fineRange = { min = 5000, max = 100000 },
    acceptRequired = true,
    defaultDueDays = 14
}

-- Penalty points and licence suspension.  Drivers accumulate penalty points
-- when receiving traffic tickets.  When they exceed `maxPoints` their
-- licence is revoked for `suspensionDays`.  Integration with driving school
-- and licence scripts is required for a full implementation.
Config.PenaltyPoints = {
    maxPoints = 12,
    suspensionDays = 30
}

-- Tax configuration.  Businesses on your server may pay monthly taxes.  These
-- values provide defaults but can be altered via server-side logic to suit
-- your economy.  Set `allowBackPayments` to true if you want companies
-- to pay outstanding taxes for previous months.  `automaticDeductionMonths`
-- defines how many months of non-payment are tolerated before the tax is
-- automatically deducted.
Config.Taxes = {
    allowBackPayments = true,
    automaticDeductionMonths = 3,
    latePaymentPercent = 15 -- per month
}

-- Jobs that may access the VIN check menu.  These roles can view vehicle
-- information (owner, insurance status, etc.) via a special interface.
Config.VINCheckJobs = {
    'police',
    'sheriff',
    'clerk'
}

-- Do you want to send phone notifications when a resume/application is accepted or rejected?
-- If enabled the system will attempt to send an email via the player’s
-- smartphone.  Supports qb-phone, qs-smartphone-pro, yseries, lb-phone and okokPhone.
Config.SendPhoneMessageAboutResume = true

-- Toggle paychecks functionality.  When false the city hall will not manage
-- paycheck balances or allow collection of paychecks via the menu.  Set to
-- false if your server uses its own paycheck system.
Config.UsePaychecks = true

-- UseVehicleType determines whether your owned_vehicles or player_vehicles table
-- contains a `type` column.  If your framework does not store the vehicle
-- type (e.g. qb‑core), set this to false to avoid SQL errors when
-- selling or transferring vehicles.
Config.UseVehicleType = false

-- Societies for insurance payouts.  When players purchase health or vehicle
-- insurance a percentage of the fee can be routed to these societies.  Set
-- society names to nil to disable society payouts.
Config.HealthInsurancerSociety = 'society_health'
Config.HealthInsuranceMoneyToSocietyPercent = 20
Config.VehiclesInsurancerSociety = 'society_insurance'
Config.VehiclesInsurancesMoneyToSocietyPercent = 20

-- Vehicle sale agreement settings.  When a vehicle is sold both buyer and seller
-- may receive a copy of the signed contract.  You can disable the copies
-- individually or change the item name to match your inventory.
Config.VehicleSaleAgreement = {
    GiveSignedItemToSeller = true,
    GiveSignedItemToBuyer = true,
    SignedItemName = 'signed_vehicle_sale_agreement',
    UseOnCommand = false,
    CommandName = 'sellvehicle'
}

-- Optional job list with icons.  Each entry maps a job name to a label and an
-- image file.  The image can be an external URL or a file stored in
-- html-react/images/ (you need to add the file to that directory).  This
-- information can be used by menus or the clerk interface.
Config.JobsList = {
    police = { label = 'Rendőr', image = 'police.png' },
    sheriff = { label = 'Sheriff', image = 'sheriff.png' },
    clerk = { label = 'Ügyintéző', image = 'clerk.png' },
    ambulance = { label = 'Mentő', image = 'ambulance.png' }
}

-- Clerk job settings.  Defines the job name used for clerks and any
-- restrictions to their actions.  Clerks can search citizens by SSN or
-- vehicles by VIN, and they can view tax and document status.
Config.ClerkJob = {
    jobName = 'clerk'
}

--[[ -------------------------------------------------------------------------
    Additional configuration options introduced in the update specification.

    UseReceipts
        When true the script enables a new billing method using physical
        receipts.  A seller must have a payment terminal and thermal paper
        in their inventory to issue a receipt.  The receipt is given to the
        buyer as an item containing the transaction details.  If false, the
        receipt functionality is disabled entirely.

    AllowToChangePlate
        Toggles whether the “Rendszámcsere” (plate change) document is
        available in the menu.  If false the entry will be hidden.  The
        document itself has a `visible` callback referencing this option.

    RequireValidLicence
        When true certain actions (such as transferring or selling a vehicle)
        will verify that the player possesses a valid driving licence.  The
        default implementation simply checks whether the player has an
        inventory item called `driver_license` via ox_inventory.  You may
        adapt this behaviour to integrate with VMS Documents V2 or other
        licence systems.

    CheckVIN
        Contains options controlling the VIN check feature.  `useOnTarget`
        toggles whether the VIN check can be triggered via a target system
        (qb-target or ox_target) by looking at a vehicle.  If false the
        menu will prompt for manual input.  `allowCopy` enables a “Copy
        VIN/Plate” button in the results window; clicking this will send
        the VIN or plate to the player via chat for easy copy/paste.
]]

Config.UseReceipts = true
Config.AllowToChangePlate = true
Config.RequireValidLicence = false

Config.CheckVIN = {
    useOnTarget = false,
    allowCopy = false
}