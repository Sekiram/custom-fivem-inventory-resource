Config = {}

-- ===================== GENERAL =====================
Config.MaxWeight = 45.0          -- kg, hard cap every player can carry
Config.Slots = 25                -- number of slots in a player's inventory (5 columns)

Config.OpenKey = 'TAB'           -- default keybind, players can rebind in FiveM keybind settings
Config.GiveDistance = 3.0        -- max distance (meters) to give an item to another player
Config.NearbyPlayerRange = 6.0   -- range used to list nearby players in the "Give" menu
Config.DropInteractDistance = 1.4 -- distance required to open a dropped bag

-- ===================== HUNGER / THIRST =====================
-- Time in seconds for the stat to fully deplete from 100 -> 0
Config.ThirstDepleteSeconds = 5400   -- ~1.5 hours (spec: 1-2 hours)
Config.HungerDepleteSeconds = 10800  -- ~3 hours   (spec: 2-4 hours)

Config.StatusTickMs = 30000           -- how often the server ticks hunger/thirst down
Config.StarvingDamageIntervalMs = 6000 -- how often you take damage at 0%
Config.StarvingDamageAmount = 3        -- health removed per damage tick when starving/dehydrated

Config.NotifyThresholds = { 50, 25, 10 } -- percentage thresholds that trigger a warning

-- ===================== STARTER ITEMS =====================
Config.StarterItems = {
    { name = 'phone',        amount = 1 },
    { name = 'bread',        amount = 3 },
    { name = 'water_bottle', amount = 3 },
}

-- ===================== ITEMS =====================
-- weight is in kilograms, per unit
Config.Items = {
    water_bottle = {
        label = 'Bottle of Water', weight = 0.5, stack = 20, icon = '💧',
        type = 'drink', thirst = 25, description = 'A bottle of fresh water.'
    },
    bread = {
        label = 'Bread', weight = 0.25, stack = 20, icon = '🍞',
        type = 'food', hunger = 15, description = 'A loaf of bread.'
    },
    sandwich = {
        label = 'Sandwich', weight = 0.3, stack = 10, icon = '🥪',
        type = 'food', hunger = 30, description = 'A tasty sandwich.'
    },
    burger = {
        label = 'Burger', weight = 0.35, stack = 10, icon = '🍔',
        type = 'food', hunger = 35, description = 'A greasy burger.'
    },
    apple = {
        label = 'Apple', weight = 0.15, stack = 10, icon = '🍎',
        type = 'food', hunger = 10, description = 'A fresh apple.'
    },
    phone = {
        label = 'Phone', weight = 0.2, stack = 1, icon = '📱',
        type = 'item', description = 'Your personal phone.'
    },
    bandage = {
        label = 'Bandage', weight = 0.1, stack = 20, icon = '🩹',
        type = 'medical', health = 25, description = 'Heals minor wounds.'
    },
    lockpick = {
        label = 'Lockpick', weight = 0.2, stack = 5, icon = '🗝️',
        type = 'item', description = 'Used to pick locks.'
    },
    cash = {
        label = 'Cash', weight = 0.0, stack = 999999, icon = '💵',
        type = 'item', description = 'Dirty money.'
    },
}
