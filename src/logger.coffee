winston = require('winston')
{Settings} = require 'madeye-common'
fs = require 'fs'

logDir = null
if process.env.MADEYE_LOG_DIR?
  logDir = process.env.MADEYE_LOG_DIR
else if process.env.MADEYE_HOME?
  logDir = "#{process.env.MADEYE_HOME}/log"
else
  logDir = "/tmp"

fs.mkdirSync logDir unless fs.existsSync logDir

consoleOptions = (app) ->
  level: 'info'
  silent: false
  colorize: true
  timestamp: (app == 'azkaban')

fileOptions = (app) ->
  level: 'info'
  filename: "#{logDir}/#{app}.log"
  timestamp: (app == 'azkaban')
  json: false

errorFileOptions = (app) ->
  level: 'error'
  filename: "#{logDir}/#{app}-error.log"
  timestamp: (app == 'azkaban')
  json: false

#Add Loggly transport
Loggly = require('winston-loggly').Loggly
logglyOptions = (logglyKey) ->
  level: 'debug'
  json: true
  subdomain: 'madeye'
  inputToken: logglyKey

logger = new winston.Logger
    transports: [
      new (winston.transports.File)(fileOptions('azkaban')),
      #new winston.transports.File errorFileOptions,
      new (winston.transports.Console)(consoleOptions('azkaban')),
      new (Loggly)(logglyOptions(Settings.logglyAzkabanKey))
    ]
  #This is breaking tests, since it swallows exceptions that mocha needs to fail a test.
    #exceptionHandlers: [
      #new winston.transports.File filename: ERROR_FILENAME
    #]

apogeeLogger = new winston.Logger
    transports: [
      new (winston.transports.File)(fileOptions('apogee-client')),
      #new winston.transports.File errorFileOptions,
      new (winston.transports.Console)(consoleOptions('apogee')),
      new (Loggly)(logglyOptions(Settings.logglyApogeeKey))
    ]

dementorLogger = new winston.Logger
    transports: [
      new (winston.transports.File)(fileOptions('dementor')),
      #new winston.transports.File errorFileOptions,
      new (winston.transports.Console)(consoleOptions('dementor')),
      new (Loggly)(logglyOptions(Settings.logglyDementorKey))
    ]

exports.logger = logger
exports.dementorLogger = dementorLogger
exports.apogeeLogger = apogeeLogger

