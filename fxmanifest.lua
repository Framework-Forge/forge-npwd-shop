fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Forge Devs'
description 'Loja e central de recuperacao do Forge NPWD'
version '1.0.2'

dependencies {
    'pr_bridge',
    'forge-npwd'
}

shared_scripts {
    '@pr_bridge/init.lua',
    '@forge-npwd/compat/app.lua',
    'config.lua'
}

client_script 'client/main.lua'
server_script 'server/main.lua'

-- Legacy dependency names; export routing remains inside forge-npwd.
provide 'forge-phone-shop'

server_script 'server/version.lua'
