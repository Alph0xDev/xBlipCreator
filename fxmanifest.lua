fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Alph0xDev'
description 'Blip Manager system'
version '1.0'

files {
    'locales/*.json'
}

shared_script {
    '@ox_lib/init.lua',
    'shared/cfg.lua'
}
client_scripts {
    'client/framework.lua',
    'client/cl.lua'
}
server_scripts {
    'server/sv.lua'
}