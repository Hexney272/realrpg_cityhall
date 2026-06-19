--[[
    Item definitions for RealRPG City Hall.  Copy the contents of this file
    into your ox_inventory/data/items.lua or merge accordingly.  Each item
    uses metadata to store serial numbers and issue dates.  When adding new
    documents remember to add them here and in Config.Documents.
]]

['id_card'] = {
    label = 'Személyi igazolvány',
    weight = 0,
    stack = false,
    close = true,
    description = 'Hivatalos személyi igazolvány, egyedi sorszámmal.',
    client = {
        image = 'id_card.png',
        formatMetadata = function(metadata)
            return ('Sorszám: %s\nKiadás ideje: %s'):format(metadata.serial, os.date('%Y.%m.%d', metadata.issuedAt))
        end
    }
},

['vehicle_sale_agreement'] = {
    label = 'Adásvételi szerződés',
    weight = 0,
    stack = false,
    close = true,
    description = 'Jármű adásvételi szerződés',
    client = {
        image = 'vehicle_sale_agreement.png',
        formatMetadata = function(metadata)
            return ('Sorszám: %s\nKiadás ideje: %s'):format(metadata.serial, os.date('%Y.%m.%d', metadata.issuedAt))
        end
    }
},

['vehicle_reregistration'] = {
    label = 'Átírási kérelem',
    weight = 0,
    stack = false,
    close = true,
    description = 'Jármű tulajdonjog átírására szolgáló dokumentum',
    client = {
        image = 'vehicle_reregistration.png',
        formatMetadata = function(metadata)
            return ('Sorszám: %s\nKiadás ideje: %s'):format(metadata.serial, os.date('%Y.%m.%d', metadata.issuedAt))
        end
    }
},

['plate_change'] = {
    label = 'Rendszámcsere dokumentum',
    weight = 0,
    stack = false,
    close = true,
    description = 'Rendszámcsere kérelmi dokumentum',
    client = {
        image = 'plate_change.png',
        formatMetadata = function(metadata)
            return ('Sorszám: %s\nKiadás ideje: %s'):format(metadata.serial, os.date('%Y.%m.%d', metadata.issuedAt))
        end
    }
},

-- Insurance certificate item – optional, used if you want a tangible item for
-- insurance.  Players could show this to police to prove coverage.  The
-- metadata stores expiry date.
['insurance_certificate'] = {
    label = 'Biztosítási kötvény',
    weight = 0,
    stack = false,
    close = true,
    description = 'Járműbiztosítási kötvény',
    client = {
        image = 'insurance_certificate.png',
        formatMetadata = function(metadata)
            return ('Rendszám: %s\nÉrvényes: %s'):format(metadata.plate or 'ismeretlen', os.date('%Y.%m.%d', metadata.expiresAt))
        end
    }
},

-- Official, signed vehicle sale agreement.  This item is given to both
-- buyer and seller when a vehicle sale is completed, if enabled in the
-- configuration.  The metadata stores the serial number, seller, buyer and
-- issue date.
['signed_vehicle_sale_agreement'] = {
    label = 'Aláírt adásvételi szerződés',
    weight = 0,
    stack = false,
    close = true,
    description = 'Hivatalosan aláírt jármű adásvételi szerződés',
    client = {
        image = 'signed_vehicle_sale_agreement.png',
        formatMetadata = function(metadata)
            return ('Sorszám: %s\nEladó: %s\nVevő: %s\nKiadás ideje: %s'):format(
                metadata.serial or 'ismeretlen',
                metadata.seller or 'ismeretlen',
                metadata.buyer or 'ismeretlen',
                os.date('%Y.%m.%d', metadata.issuedAt)
            )
        end
    }
},

-- *** Receipt system items ***
-- A mobil fizetési terminál, amelyet az eladó használhat nyugták kiállításához.
['payment_terminal'] = {
    label = 'Fizetési terminál',
    weight = 1,
    stack = false,
    close = true,
    description = 'Hordozható fizetési terminál, amellyel számlákat és nyugtákat lehet kiállítani. Használatához hőpapírra van szükség.',
    client = {
        image = 'payment_terminal.png',
        formatMetadata = function(metadata)
            return ('Eszköz azonosító: %s'):format(metadata.serial or 'ismeretlen')
        end
    }
},

-- Hőpapír tekercs.  Egy nyomtatott nyugta egy darabot fogyaszt belőle.
['thermal_paper'] = {
    label = 'Hőpapír',
    weight = 0,
    stack = true,
    close = true,
    description = 'Hőpapír tekercs, amely a fizetési terminálba kerül. Minden nyugta kiállítása egy tekercset fogyaszt.',
    client = {
        image = 'thermal_paper.png'
    }
},

-- Nyugta (receipt) tárgy.  Az eladó állítja ki a vásárlónak.  A metaadatokban
-- tároljuk a termék leírását, a mennyiséget és az árat, hogy később
-- visszakereshető legyen.
['receipt'] = {
    label = 'Nyugta',
    weight = 0,
    stack = false,
    close = true,
    description = 'Hivatalos nyugta egy vásárlásról. Metaadatokban tartalmazza a tranzakció részleteit.',
    client = {
        image = 'receipt.png',
        formatMetadata = function(metadata)
            local lines = {}
            if metadata.description then table.insert(lines, ('Tétel: %s'):format(metadata.description)) end
            if metadata.quantity then table.insert(lines, ('Mennyiség: %d'):format(metadata.quantity)) end
            if metadata.total then table.insert(lines, ('Összeg: %d Ft'):format(metadata.total)) end
            if metadata.issuedAt then table.insert(lines, ('Kiadás ideje: %s'):format(os.date('%Y.%m.%d', metadata.issuedAt))) end
            return table.concat(lines, '\n')
        end
    }
}