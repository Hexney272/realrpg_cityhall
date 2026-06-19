--[[
    RealRPG Városháza script

    This resource implements a light‑weight city hall system for your FiveM server.  It
    allows players to order documents, purchase vehicle insurance and handle basic
    administrative tasks such as fines and invoices.  A clerk job can search citizen
    and vehicle information, while companies may pay configured taxes.  The design
    intentionally keeps things modular – you can expand on these foundations to suit
    your own economy or role‑play needs.

    Required dependencies:
      * ox_lib – used for context menus, input dialogs and notifications
      * oxmysql – database abstraction for persistent storage
      * ox_inventory – for item metadata and document items

    Author: RealRPG Community
]]

fx_version 'cerulean'
game 'gta5'

author 'RealRPG Community'
description 'Modular city hall (városháza) system with insurance, documents, fines and clerk tools.'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

-- The city hall menus are implemented using ox_lib context menus; no custom
-- NUI is used.  The HTML files are kept for reference only but not loaded.