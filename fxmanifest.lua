fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ps-inventory'
author 'Built for standalone FiveM servers'
description 'Standalone drag & drop inventory with hunger/thirst, drop/split/separate/give'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'data/players.json'
}
