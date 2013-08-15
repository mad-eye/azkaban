clc = require 'cli-color'

levels =
  error: 0
  warn: 1
  info: 2
  debug: 3
  trace: 4

class LogListener
  constructor: (options) ->
    options ?= {}
    level = options.logLevel ? 'info'
    @logLevel = levels[level]
    @specificLevels = {}

  listen: (emitter, name, level) ->
    level ?= @logLevel
    level = levels[level]

    prefix = if name then "[#{name}] " else ""
    emitter.on 'error', (err) ->
      console.error prefix, clc.red('ERROR:'), err.message
      shutdown(err.code ? 1)

    if level >= levels['warn']
      emitter.on 'warn', (msgs...) ->
        console.error prefix, clc.bold('Warn:'), msgs

    if level >= levels['info']
      emitter.on 'info', (msgs...) ->
        console.log prefix, 'Info:',  msgs

    if level >= levels['debug']
      emitter.on 'debug', (msgs...) ->
        console.log clc.blackBright prefix, 'Debug:', msgs
    
    if level >= levels['trace']
      emitter.on 'trace', (msgs...) ->
        console.log clc.blackBright prefix, 'Trace:', msgs

module.exports = LogListener
