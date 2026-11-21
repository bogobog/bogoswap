-- BogoSwap: swap an item into an equipment slot depending on whether a buff is present.
-- Start: /lua run bogoswap            (starts paused)
--        /lua run bogoswap pause=no   (starts running)
local mq = require('mq')
require('ImGui')

local VERSION = '0.3.0'

local log = require('bogoswap.core.log')
local args = require('bogoswap.core.args')
local config = require('bogoswap.core.config')
local game = require('bogoswap.core.game')
local swap = require('bogoswap.core.swap')
local commands = require('bogoswap.core.commands')
local tlo = require('bogoswap.core.tlo')
local panel = require('bogoswap.ui.panel')

local opts, argWarnings = args.parse({ ... })
for _, w in ipairs(argWarnings) do log.warn('%s', w) end

if not game.inGame() then
    log.info('Waiting until you are in game...')
    while not game.inGame() do mq.delay(1000) end
end

local state = {
    version = VERSION,
    running = true,
    paused = opts.pause,
    ui = { open = true, edit = {}, seen = {} },
}
state.cfg, state.cfgPath = config.load(game.server(), game.charName())
log.applyChannels(state.cfg.Debug)

local n = log.nextAction()
log.debug('cmd', n, 'started %s (%s)', opts.pause and 'paused' or 'running', opts.pauseSource)
if opts.pause then
    log.info('v%s started \ayPAUSED\ax. Click Resume in the BogoSwap window or type /bogoswap resume.', VERSION)
    log.info('To start running instead: /lua run bogoswap pause=no')
else
    log.info('v%s started and running (%s). /bogoswap pause to pause.', VERSION, opts.pauseSource)
end
for _, w in ipairs(commands.validate(state)) do log.warn('%s', w) end
if not game.exchangeLoaded() then
    log.warn('MQ2Exchange is not loaded, and BogoSwap needs it to swap. Load it with /plugin mq2exchange')
end
log.info('/bogoswap help lists commands.')

local function onCommand(...) commands.handle(state, ...) end
mq.bind('/bogoswap', onCommand)
mq.bind('/bswap', onCommand)
mq.imgui.init('BogoSwap', function() panel.draw(state) end)
tlo.register(state)

while state.running do
    local force = state.force
    state.force = nil
    swap.tick(state, mq.gettime(), force)
    mq.delay(state.cfg.TickMs)
end

mq.unbind('/bogoswap')
mq.unbind('/bswap')
tlo.unregister(state)
log.info('Stopped.')
