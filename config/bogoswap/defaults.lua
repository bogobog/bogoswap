-- BogoSwap defaults. Each character's settings live in <MQ config>/BogoSwap/<server>_<character>.lua,
-- which is created from these values the first time that character runs BogoSwap.
-- Must match BUILTIN_DEFAULTS in lua/bogoswap/core/config.lua (a test checks this).
return {
    -- The four settings; set them with /bogoswap set or the window.
    TriggerEffectName = '',  -- buff or song to watch for
    SwapEquipmentSlot = '',  -- equipment slot, e.g. mainhand, offhand, range, charm
    MatchItemName = '',      -- item to equip while the effect is present
    NoMatchItemName = '',    -- item to equip while the effect is absent

    OnlyInCombat = false,    -- when true, only swap while in combat (see the README)

    TickMs = 250,    -- how often to check, in milliseconds
    SettleMs = 750,  -- how long to wait after a swap before checking it worked
    RetryMs = 3000,  -- how long after a swap that didn't work before trying again

    Debug = { swap = false, guard = false, config = false, cmd = false, ui = false },

    -- Runtime state kept across restarts: the offhand item taken off to equip a two-hander.
    State = { StashedOffhandItem = '' },
}
