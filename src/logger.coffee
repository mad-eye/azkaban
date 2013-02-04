winston = require('winston')
{Settings} = require 'madeye-common'
fs = require 'fs'

logDir = process.env.MADEYE_LOG_DIR
if not logDir and process.env.MADEYE_HOME
  logDir = "#{process.env.MADEYE_HOME}/log" 

unless logDir
  logDir = "/tmp"

fs.mkdirSync logDir unless fs.existsSync logDir

consoleOptions =
  level: 'info'
  silent: false
  colorize: true
  timestamp: true

fileOptions =
  level: 'info'
  filename: "#{logDir}/azkaban.log"
  timestamp: true
  json: false

ERROR_FILENAME = "#{logDir}/azkaban-error.log"
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
#This is breaking tests, since it swallows exceptions that mocha needs to fail a test.
#winston.handleExceptions new winston.transports.File errorFileOptions
exports.logger = winston
