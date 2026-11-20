Config = {}
Config.VersionCheck = true

Config.Command = 'forgephoneshop'
Config.PaymentAccounts = { 'cash', 'bank' }
Config.RecoveryPrice = 750
Config.InteractionDistance = 2.0
Config.DrawDistance = 15.0
Config.PhoneExportTimeout = 15000
Config.CallbackTimeout = 25000

Config.Models = {
    {
        id = 'forge_one',
        label = 'Forge One',
        description = 'Modelo equilibrado para uso diario.',
        price = 2500,
        icon = 'phone',
        colors = {
            { id = 'black', label = 'Preto' },
            { id = 'white', label = 'Branco' },
            { id = 'blue', label = 'Azul' }
        }
    },
    {
        id = 'forge_pro',
        label = 'Forge Pro',
        description = 'Modelo premium da linha Forge.',
        price = 4500,
        icon = 'phone-fill',
        colors = {
            { id = 'black', label = 'Preto' },
            { id = 'silver', label = 'Prata' },
            { id = 'gold', label = 'Dourado' }
        }
    },
    {
        id = 'forge_ultra',
        label = 'Forge Ultra',
        description = 'Aparelho topo de linha.',
        price = 7000,
        icon = 'phone-vibrate-fill',
        colors = {
            { id = 'black', label = 'Preto' },
            { id = 'graphite', label = 'Grafite' },
            { id = 'red', label = 'Vermelho' }
        }
    }
}

Config.Locations = {
    {
        label = 'Forge NPWD Store',
        coords = vector3(-656.83, -858.67, 24.49),
        marker = {
            enabled = true,
            type = 2,
            color = { r = 255, g = 122, b = 26, a = 180 }
        },
        blip = {
            enabled = true,
            sprite = 521,
            color = 47,
            scale = 0.75
        }
    }
}

