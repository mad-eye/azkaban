browserChannel = require('browserchannel').server
connect = require('connect')
express = require('express')
http = require('http')
path = require('path')
{SocketConnection} = require './connectors/SocketConnection'
{DementorChannel} = require './channels/DementorChannel'
{Settings} = require 'madeye-common'
{ServiceKeeper} = require './ServiceKeeper'

app = module.exports = express()

require('./routes')(app)

app.configure ->
  app.set('port', Settings.httpPort || 4004)
  app.use(express.favicon())
  app.use(express.logger('dev'))
  app.use(express.bodyParser())
  app.use(express.methodOverride())
  app.use(app.router)

app.configure 'development', ->
  app.use(express.errorHandler())

app.configure 'test', ->
  app.use(express.errorHandler())


socketServer = ServiceKeeper.getSocketServer()
socketServer.listen Settings.bcPort


http.createServer(app).listen(app.get('port'), ->
  console.log("Express server listening on port " + app.get('port')))
