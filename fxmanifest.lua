fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'
author 'AWZ Code'
description 'AWZ Detonator - clean VORP RedM dynamite, fuse and detonator system'
version '1.2.0'

shared_scripts {
    'config/config.lua',
    'locales/it.lua',
    'locales/en.lua',
    'locales/fr.lua',
    'locales/de.lua',
    'shared/locale.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

dependencies {
    'vorp_inventory',
    'oxmysql'
}
