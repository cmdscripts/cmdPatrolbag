fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'cmdscripts'
description 'Server-authoritative multi-bag system for ESX and QBox'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'locale.lua',
    'shared.lua',
}

client_scripts {
    'client/main.lua',
    'client/carry.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/main.lua',
    'server/hooks.lua',
}

files {
    'config.lua',
    'locales/*.json',
}

dependencies {
    'ox_lib',
    'ox_inventory',
}
