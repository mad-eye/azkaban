browserChannel = require('browserchannel').server
connect = require('connect')
express = require('express')
http = require('http')
path = require('path')

app = module.exports = express()

routes = require('./routes')
dementor = require('./routes/dementor')

app.configure ->
  app.set('port', process.env.PORT || 4004)
  app.use(express.favicon())
  app.use(express.logger('dev'))
  app.use(express.bodyParser())
  app.use(express.methodOverride())
  app.use(app.router)
  app.use(express.static(path.join(__dirname, 'public')))
  app.set('mongo.hostname', 'mongo.madeye.io') #FIXME
  app.set('mongo.port', 27017) #FIXME
  app.set('bchannel.port', 4321) #FIXME
  app.set('apogee.hostname', 'apogee.madeye.io')

app.configure 'development', ->
  app.use(express.errorHandler())
  app.set('mongo.hostname', 'localhost') #FIXME
  app.set('mongo.port', 27017) #FIXME
  app.set('bchannel.port', 4321) #FIXME
  app.set('apogee.hostname', 'apogee.madeye.io')

app.configure 'test', ->
  app.set('port', 4001)
  app.use(express.errorHandler())
  app.set('mongo.hostname', 'localhost') #FIXME
  app.set('mongo.port', 27017) #FIXME
  app.set('bchannel.port', 4321) #FIXME
  app.set('apogee.hostname', 'apogee.madeye.io')

app.get('/', routes.index)
app.get('/init', dementor.init)

http.createServer(app).listen(app.get('port'), ->
  console.log("Express server listening on port " + app.get('port')))

#TOOD add browserchannel code
