express = require('express')
http = require('http')
io = require 'socket.io'
{Settings} = require 'madeye-common'
{ServiceKeeper} = require './ServiceKeeper'
cors = require './cors'
flow = require 'flow'
mongoose = require 'mongoose'
{logger} = require './src/logger'

app = module.exports = express()

app.configure ->
  app.set('port', Settings.httpPort || 4004)
  app.use(express.favicon())
  app.use(express.logger('dev'))
  app.use(express.bodyParser())
  app.use(express.methodOverride())
  app.use(cors())
  app.use(app.router)

app.configure 'development', ->
  app.use(express.errorHandler())

app.configure 'test', ->
  app.use(express.errorHandler())

require('./routes')(app)

#Set up mongo/mongoose
#TODO: Put this in settings?
DB_NAME = 'meteor'
mongoUrl = "mongodb://#{Settings.mongoHost}:#{Settings.mongoPort}/#{DB_NAME}"
console.log "Connecting to mongo #{mongoUrl}"
mongoose.connect mongoUrl

#Set up http/socket servers
httpServer = http.createServer(app)
socketServer = io.listen httpServer
dementorChannel = ServiceKeeper.instance().getDementorChannel()
socketServer.sockets.on 'connection', (socket) =>
  dementorChannel.attach socket
httpServer.listen app.get('port'), ->
  logger.info "Express server listening on port " + app.get('port')

socketServer.configure ->
  socketServer.set 'log level', 2
  

# Shutdown section
SHUTTING_DOWN = false

shutdown = (returnVal=0) ->
  #Multiple ^C will allow exit in haste
  process.exit(returnVal || 1) if SHUTTING_DOWN # || not ?, because we don't want 0
  shutdownGracefully(returnVal)

shutdownGracefully = (returnVal) ->
  return if SHUTTING_DOWN
  SHUTTING_DOWN = true
  logger.debug "Shutting down Azkaban gracefully."
  flow.exec ->
    dementorChannel.destroy this.MULTI(),
    httpServer.close this.MULTI()
  , ->
    process.exit returnVal ? 0
 
  setTimeout ->
    logger.warn "Could not close connections in time, forcefully shutting down"
    process.exit returnVal || 1
  , 30*1000

process.on 'SIGINT', ->
  shutdown()

process.on 'SIGTERM', ->
  shutdown()
