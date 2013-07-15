winston = require('winston')
{Settings} = require 'madeye-common'

logDir = null
if process.env.MADEYE_LOG_DIR?
  logDir = process.env.MADEYE_LOG_DIR
else if process.env.MADEYE_HOME?
  logDir = "#{process.env.MADEYE_HOME}/log"
else
  logDir = "/tmp"

fs = require 'fs'
fs.mkdirSync logDir unless fs.existsSync logDir

consoleOptions = (app) ->
  level: 'debug'
  silent: false
  colorize: true
  timestamp: true

fileOptions = (app) ->
  level: 'info'
  filename: "#{logDir}/#{app}.log"
  timestamp: true
  json: false

#Add Loggly transport
Loggly = require('winston-loggly').Loggly
logglyOptions = (logglyKey) ->
  level: 'debug'
  json: true
  subdomain: 'madeye'
  inputToken: logglyKey

makeLogger = (fileName, consoleName, logglyKey) ->
  transports = [
    new (winston.transports.File)(fileOptions(fileName)),
    new (Loggly)(logglyOptions(logglyKey))
  ]
  if process.env.MADEYE_DEBUG
    transports.push new (winston.transports.Console)(consoleOptions(consoleName))

  return new winston.Logger transports: transports

logger = makeLogger 'azkaban', 'azkaban', Settings.logglyAzkabanKey

apogeeLogger = makeLogger 'apogee-client', 'apogee', Settings.logglyApogeeKey

dementorLogger = makeLogger 'dementor', 'dementor', Settings.logglyDementorKey

exports.logger = logger
exports.dementorLogger = dementorLogger
exports.apogeeLogger = apogeeLogger

