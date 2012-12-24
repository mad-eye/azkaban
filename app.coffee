express = require('express')
http = require('http')
{Settings} = require 'madeye-common'
{ServiceKeeper} = require './ServiceKeeper'
cors = require './cors'
flow = require 'flow'

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

socketServer = ServiceKeeper.getSocketServer()
socketServer.listen Settings.bcPort

httpServer = http.createServer(app).listen(app.get('port'), ->
  console.log("Express server listening on port " + app.get('port')))

# Shutdown section
SHUTTING_DOWN = false

shutdownGracefully = ->
  return if SHUTTING_DOWN
  SHUTTING_DOWN = true
  console.log "Shutting down gracefully."
  flow.exec ->
    socketServer.destroy this.MULTI(),
    httpServer.close this.MULTI()
  , ->
    console.log "Closed out connections."
    process.exit 0
 
  setTimeout ->
    console.error "Could not close connections in time, forcefully shutting down"
    process.exit(1)
  , 30*1000

process.on 'SIGINT', ->
  process.exit(1) if SHUTTING_DOWN #Multiple ^C will allow exit in haste
  console.log 'Received SIGINT.'
  shutdownGracefully()

process.on 'SIGTERM', ->
  process.exit(1) if SHUTTING_DOWN
  console.log "Received kill signal (SIGTERM)"
  shutdownGracefully()
 
