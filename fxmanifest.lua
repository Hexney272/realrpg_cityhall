--[[
    RealRPG Városháza script

    This resource implements a city hall system for your FiveM server with a
    custom NUI interface.  It allows players to order documents, purchase
    vehicle insurance and handle basic administrative tasks such as fines
    and invoices.  A clerk job can search citizen and vehicle information,
    while companies may pay configured taxes.

    Required dependencies:
      * ox_lib – used for the [E] interaction prompt and fallback notifications
      * oxmysql – database abstraction for persistent storage
      * ox_inventory – for item metadata and document items
      * es_extended (ESX) – framework for player data, money and jobs

    Author: RealRPG Community
]]

fx_version 'cerulean'
game 'gta5'

author 'RealRPG Community'
description 'Modular city hall (városháza) system with custom NUI, insurance, documents, fines and clerk tools.'

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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
