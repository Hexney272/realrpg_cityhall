# RealRPG Városháza (City Hall)

Moduláris városháza rendszer FiveM szerverekhez. A script lehetővé teszi okmányok igénylését, kötelező biztosítás kötését, bírságok és számlák kiállítását, VIN ellenőrzést, valamint nyugtarendszer használatát.

---

## Követelmények

| Dependency | Leírás |
|---|---|
| [ox_lib](https://github.com/overextended/ox_lib) | Context menük, input dialógusok, értesítések |
| [oxmysql](https://github.com/overextended/oxmysql) | MySQL adatbázis kezelés |
| [ox_inventory](https://github.com/overextended/ox_inventory) | Item rendszer, metadata kezelés |
| [es_extended (ESX)](https://github.com/esx-framework/esx_core) | Framework (játékos adatok, pénz, munkák) |

---

## Telepítés

1. Másold a `realrpg_cityhall` mappát a szervered `resources` könyvtárába.
2. Add hozzá a `server.cfg`-hez:
   ```
   ensure ox_lib
   ensure oxmysql
   ensure ox_inventory
   ensure es_extended
   ensure realrpg_cityhall
   ```
3. Az `ox_inventory_items.lua` tartalmát másold be az `ox_inventory/data/items.lua` fájlba.
4. A szükséges adatbázis táblákat a script automatikusan létrehozza induláskor.

---

## Funkciók

### Okmányok igénylése
A játékosok a városházán különböző okmányokat igényelhetnek:

| Okmány | Ár | Feldolgozási idő |
|---|---|---|
| Személyi igazolvány | 20 000 Ft | 600 másodperc (10 perc) |
| Adásvételi szerződés | 5 000 Ft | Azonnal |
| Átírás | 7 500 Ft | Azonnal |
| Rendszámcsere | 100 000 Ft | Azonnal |

- A rendszámcsere csak akkor elérhető, ha `Config.AllowToChangePlate = true`.
- A feldolgozási idővel rendelkező okmányokat a rendszer sorba állítja, majd automatikusan kiadja.

### Kötelező biztosítás
- A játékosok kötelező biztosítást köthetnek járműveikre.
- Ár: 50 000 Ft (konfigurálható)
- Érvényesség: 30 nap (konfigurálható)
- Biztosított járművek kedvezményes javítást kaphatnak (25% kedvezmény).
- A biztosítás társaságoknak is fizet (20% a society-nek).

### Bírság / Számla kiállítása
Csak jogosult munkakörökkel (`police`, `sheriff`, `clerk`) rendelkező játékosok használhatják.

**Szabálysértési bírság:**
- Megadandó: cél játékos ID, sértés leírása, összeg, fizetési határidő
- Összeg korlát: 5 000 - 100 000 Ft

**Céges számla:**
- Megadandó: vásárló ID, termék/szolgáltatás leírása, mennyiség, egységár, adó (%)
- Fizetési határidő: 14 nap (alapértelmezés)

### VIN ellenőrzés
Jogosult munkakörök (`police`, `sheriff`, `clerk`) számára elérhető.

- **Manuális mód** (`Config.CheckVIN.useOnTarget = false`): Rendszám vagy VIN szám megadásával.
- **Target mód** (`Config.CheckVIN.useOnTarget = true`): Az előtted álló jármű automatikus felismerésével.
- Megjelenített adatok: tulajdonos, rendszám, típus, biztosítási státusz.
- Opcionális: rendszám másolás chatbe, közvetlen bírság kiállítás az eredményből.

### Nyugtarendszer
Csak akkor aktív, ha `Config.UseReceipts = true`.

- A kiállítónak szüksége van egy **fizetési terminálra** és **hőpapírra** az inventoryban.
- Minden nyugta kiállítás 1 db hőpapírt fogyaszt.
- A vásárló megkapja a nyugtát itemként, metaadatokkal (leírás, mennyiség, összeg, dátum).

### Büntetőpontok
- Járművezetők büntetőpontokat gyűjtenek szabálysértések után.
- Maximum: 12 pont → 30 napos jogosítvány felfüggesztés.
- (Teljes implementációhoz autósiskola/jogosítvány script integrálása szükséges.)

### Adórendszer
- Cégek havi adót fizethetnek.
- Hátralékok engedélyezhetők (`Config.Taxes.allowBackPayments`).
- Késedelmi pótlék: 15%/hó.
- 3 hónap nemfizetés után automatikus levonás.

### Telefonos értesítések
Ha `Config.SendPhoneMessageAboutResume = true`, a rendszer megpróbál üzenetet küldeni a játékos telefonjára. Támogatott telefon resource-ok:
- qb-phone
- qs-smartphone-pro
- yseries
- lb-phone
- okokPhone
- gksphone

Ha nincs támogatott telefon resource, játékon belüli értesítést küld.

---

## Parancsok

| Parancs | Leírás | Jogosultság |
|---|---|---|
| `/billings` | Számlák és bírságok keresése név alapján | Csak `clerk` munkakör |

---

## Interakció

A városháza menü a konfigurált koordinátáknál (`Config.CityHall.coords`) érhető el. Amikor a játékos a markeren belül áll és megnyomja az **[E]** gombot, megnyílik a főmenü.

---

## Adatbázis táblák

A script automatikusan létrehozza a következő táblákat:

| Tábla | Leírás |
|---|---|
| `realrpg_insurances` | Járműbiztosítások (rendszám, tulajdonos, lejárat) |
| `realrpg_fines` | Bírságok (kibocsátó, címzett, összeg, leírás, határidő) |
| `realrpg_invoices` | Számlák (kibocsátó, címzett, mennyiség, egységár, adó) |
| `realrpg_custom_taxes` | Egyéni adók (azonosító, összeg, leírás) |

---

## Exportok (Server-side)

### `giveBill(src, billType, data, giveItem, cb)`
Bírság vagy számla kiállítása játékosnak programból (pl. más resource-ból).

**Paraméterek:**
- `src` (number) – Cél játékos server ID
- `billType` (string) – `'ticket'`, `'traffic-ticket'` vagy `'invoice'`
- `data` (table) – Tranzakció adatai:
  - Ticket: `{ amount, violation/description, dateToPay, issuerIdentifier }`
  - Invoice: `{ invoiceData = {{ qty, unitPrice, description }}, taxFromInvoice, issuerIdentifier }`
- `giveItem` (any) – Nem használt (kompatibilitás miatt)
- `cb` (function) – Callback az eredménnyel

**Példa:**
```lua
exports['realrpg_cityhall']:giveBill(playerId, 'ticket', {
    amount = 15000,
    violation = 'Gyorshajtás',
    dateToPay = 7,
    issuerIdentifier = 'system'
}, false, function(result)
    print('Bírság kiállítva, ID:', result)
end)
```

---

### `getPlayerJobLabel(src)`
Visszaadja a játékos munkakörének megjelenítési nevét.

**Paraméterek:**
- `src` (number) – Játékos server ID

**Visszatérési érték:** string vagy nil

```lua
local label = exports['realrpg_cityhall']:getPlayerJobLabel(playerId)
print(label) -- pl. "Rendőr"
```

---

### `getVehicleInsurance(plate, cb)`
Lekérdezi egy jármű biztosítási állapotát.

**Paraméterek:**
- `plate` (string) – Rendszám
- `cb` (function) – Callback a következő tábla-val:
  - `insured` (boolean) – Van-e érvényes biztosítás
  - `expiresAt` (number) – Lejárati Unix timestamp
  - `purchasedAt` (number) – Vásárlás ideje
  - `owner` (string) – Vásárló identifier

**Példa:**
```lua
exports['realrpg_cityhall']:getVehicleInsurance('ABC123', function(info)
    if info.insured then
        print('Biztosítva, lejárat:', os.date('%Y.%m.%d', info.expiresAt))
    else
        print('Nincs érvényes biztosítás')
    end
end)
```

---

### `addVehicleInsurance(plate, identifier, durationDays, cb)`
Biztosítás hozzáadása vagy meghosszabbítása programból.

**Paraméterek:**
- `plate` (string) – Rendszám
- `identifier` (string) – Fizető azonosítója (ESX identifier vagy society)
- `durationDays` (number) – Hány napra szól
- `cb` (function) – Callback boolean eredménnyel

**Példa:**
```lua
exports['realrpg_cityhall']:addVehicleInsurance('ABC123', 'steam:110000123456789', 30, function(success)
    if success then print('Biztosítás hozzáadva') end
end)
```

---

### `addPlayerCustomTaxToPay(identifier, amount, description, cb)`
Egyéni adó kivetése játékosra (offline is működik).

**Paraméterek:**
- `identifier` (string) – Játékos identifier
- `amount` (number) – Összeg
- `description` (string) – Adó leírása
- `cb` (function) – Callback boolean eredménnyel

**Példa:**
```lua
exports['realrpg_cityhall']:addPlayerCustomTaxToPay('steam:110000123456789', 50000, 'Ingatlanadó', function(success)
    if success then print('Adó kiírva') end
end)
```

---

## Inventory itemek

A script a következő itemeket használja (`ox_inventory_items.lua`):

| Item | Leírás |
|---|---|
| `id_card` | Személyi igazolvány |
| `vehicle_sale_agreement` | Adásvételi szerződés |
| `vehicle_reregistration` | Átírási kérelem |
| `plate_change` | Rendszámcsere dokumentum |
| `insurance_certificate` | Biztosítási kötvény |
| `signed_vehicle_sale_agreement` | Aláírt adásvételi szerződés |
| `payment_terminal` | Fizetési terminál (nyugtarendszerhez) |
| `thermal_paper` | Hőpapír (nyugta nyomtatáshoz) |
| `receipt` | Nyugta |

---

## Konfiguráció

A teljes konfiguráció a `shared/config.lua` fájlban található. Főbb beállítások:

| Beállítás | Leírás | Alapérték |
|---|---|---|
| `Config.CityHall.coords` | Városháza marker koordináták | `vector3(-548.99, -203.21, 37.22)` |
| `Config.CityHall.markerDistance` | Marker megjelenítési távolság | 15.0 |
| `Config.CityHall.interactDistance` | Interakciós távolság | 2.5 |
| `Config.Insurance.price` | Biztosítás ára | 50 000 |
| `Config.Insurance.duration` | Biztosítás érvényessége (nap) | 30 |
| `Config.Insurance.repairDiscountPercent` | Javítási kedvezmény | 25% |
| `Config.Fines.FineJobs` | Bírságolásra jogosult munkakörök | police, sheriff, clerk |
| `Config.Fines.fineRange` | Bírság összeg korlátok | 5 000 - 100 000 |
| `Config.Fines.defaultDueDays` | Alapértelmezett fizetési határidő | 14 nap |
| `Config.VINCheckJobs` | VIN ellenőrzésre jogosult munkák | police, sheriff, clerk |
| `Config.UseReceipts` | Nyugtarendszer engedélyezése | true |
| `Config.AllowToChangePlate` | Rendszámcsere engedélyezése | true |
| `Config.RequireValidLicence` | Jogosítvány megkövetelése | false |
| `Config.CheckVIN.useOnTarget` | VIN target mód | false |
| `Config.CheckVIN.allowCopy` | Rendszám másolás engedélyezése | false |
| `Config.UsePaychecks` | Fizetések kezelése | true |
| `Config.UseVehicleType` | Jármű típus oszlop használata | false |

---

## Események (Events)

### Client Events
| Event | Leírás |
|---|---|
| `realrpg_cityhall:notify` | Értesítés megjelenítése (title, msg, type) |
| `realrpg_cityhall:documentReady` | Okmány elkészült értesítés |
| `realrpg_cityhall:vinResult` | VIN lekérdezés eredménye |
| `realrpg_cityhall:billingsResult` | Billings keresési eredmények |

### Server Events
| Event | Leírás |
|---|---|
| `realrpg_cityhall:buyInsurance` | Biztosítás vásárlás (plate) |
| `realrpg_cityhall:requestDocument` | Okmány igénylés (docId) |
| `realrpg_cityhall:issueFine` | Bírság kiállítás (targetId, data) |
| `realrpg_cityhall:issueInvoice` | Számla kiállítás (targetId, data) |
| `realrpg_cityhall:vinCheck` | VIN/rendszám lekérdezés (query) |
| `realrpg_cityhall:searchBillings` | Billings keresés (term) |
| `realrpg_cityhall:issueReceipt` | Nyugta kiállítás (targetId, data) |

---

## Jogosultságok

| Funkció | Szükséges munkakör |
|---|---|
| Okmány igénylés | Bárki |
| Biztosítás kötés | Bárki |
| Bírság kiállítás | police, sheriff, clerk |
| Számla kiállítás | police, sheriff, clerk |
| VIN ellenőrzés | police, sheriff, clerk |
| Nyugta kiállítás | police, sheriff, clerk |
| `/billings` parancs | clerk |

---

## Verzió

Jelenlegi verzió: **1.0.9** (lásd `version.lua`)

---

## Szerző

RealRPG Community
