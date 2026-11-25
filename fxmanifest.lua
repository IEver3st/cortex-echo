fx_version 'cerulean'
game 'gta5'

name 'cortex-echo'
author 'GSDMODS/CORTEX'
description 'Sound marks for deaf and hard-of-hearing players'

dependency 'cortex-lib'
lua54 'yes'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/kinds.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/perf.lua',
    'client/looks.lua',
    'client/settings.lua',
    'client/sources.lua',
    'client/world.lua',
    'client/engines.lua',
    'client/marks.lua',
    'client/cues.lua',
    'client/nui.lua',
    'client/main.lua',
}

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/*',
    'web/dist/barlow-condensed-OFL.txt',
    'locales/*.json',
    'textures/*.png',
}

escrow_ignore {
    'config.lua',
    'locales/*.json',
    'shared/locale.lua',
}
