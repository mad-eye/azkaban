winston = require('winston')
{Settings} = require 'madeye-common'

console.log "Found Settings", Settings

consoleOptions =
  level: 'info'
  silent: false
  colorize: true
  timestamp: true

fileOptions =
  level: 'info'
  filename: '/tmp/azkaban.log'
  timestamp: true
  json: false

ERROR_FILENAME = '/tmp/azkaban-error.log'
errorFileOptions =
  level: 'error'
  filename: ERROR_FILENAME
  timestamp: true
  json: false

#Add Loggly transport
Loggly = require('winston-loggly').Loggly
logglyOptions =
  level: 'debug'
  json: true
  subdomain: 'madeye'
  inputToken: Settings.logglyAzkabanKey #Azakban's key

  ###
logger = new winston.Logger
    transports: [
      new winston.transports.File fileOptions,
      new winston.transports.File errorFileOptions,
      new winston.transports.Console consoleOptions,
      new Loggly logglyOptions
    ]
    exceptionHandlers: [
      new winston.transports.File filename: ERROR_FILENAME
    ]
    ###

winston.remove winston.transports.Console
winston.add winston.transports.Console, consoleOptions
winston.add winston.transports.File, fileOptions
winston.add Loggly, logglyOptions
winston.handleExceptions new winston.transports.File errorFileOptions
exports.logger = winston
