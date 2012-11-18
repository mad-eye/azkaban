browserChannel = require('browserchannel').server
connect = require('connect')
express = require('express')
http = require('http')
path = require('path')
{SocketConnection} = require './connectors/SocketConnection'
{DementorChannel} = require './channels/DementorChannel'
{Settings}  = require './Settings'

app = module.exports = express()

require('./routes')(app)

app.configure ->
  app.set('port', Settings.httpPort || 4004)
  app.use(express.favicon())
  app.use(express.logger('dev'))
  app.use(express.bodyParser())
  app.use(express.methodOverride())
  app.use(app.router)
  app.use(express.static(path.join(__dirname, 'public')))

app.configure 'development', ->
  app.use(express.errorHandler())

app.configure 'test', ->
  app.set('port', 4001)
  app.use(express.errorHandler())


dementorConnection = new SocketConnection(new DementorChannel())
dementorConnection.listen Settings.bcPort


http.createServer(app).listen(app.get('port'), ->
  console.log("Express server listening on port " + app.get('port')))
