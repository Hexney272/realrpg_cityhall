--[[
    RealRPG Városháza script

    This resource implements a city hall system for your FiveM server with a
    custom NUI interface.  Features:
      * Okmányok igénylése (személyi, szerződések, átírás, rendszámcsere)
      * Kötelező biztosítás kötése
      * VIN ellenőrzés (rendőr/clerk számára)
      * Fizetési terminál NUI (3D nyomtatás animáció)
      * Nyugta megtekintő NUI (item használatakor megnyílik)

    Required dependencies:
      * ox_lib – used for the [E] interaction prompt and fallback notifications
      * oxmysql – database abstraction for persistent storage
      * ox_inventory – for item metadata, usable items and document items
      * es_extended (ESX) – framework for player data, money and jobs

    Author: RealRPG Community
]]

fx_version 'cerulean'
game 'gta5'

author 'RealRPG Community'
description 'City hall with custom NUI: insurance, documents, VIN check, payment terminal & receipt viewer.'

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
