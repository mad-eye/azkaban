express = require('express')
http = require('http')
{Settings} = require 'madeye-common'
{Azkaban} = require './src/azkaban'
FileController = require('./src/fileController')
BolideClient = require "./src/bolideClient"
ApogeeLogProcessor = require './src/apogeeLogProcessor'
DementorController = require('./src/dementorController')
HangoutController = require('./src/hangoutController')
StripeController = require('./src/stripeController')
{cors} = require 'madeye-common'
mongoose = require 'mongoose'
FileSyncer = require './src/fileSyncer'
{Logger} = require 'madeye-common'

Logger.onError = (err) ->
    shutdown(err.code ? 1)

log = new Logger 'app'

class Server
  constructor: ->
    @configureApp()
    @setupMongo()
    @setupServers()
    @SHUTTING_DOWN = false

  configureApp: ->
    @app = express()

    @app.configure =>
      @app.set('port', Settings.azkabanPort)
      @app.use(express.favicon())
      @app.use(express.logger('dev'))
      @app.use(express.bodyParser())
      @app.use(express.methodOverride())
      #Clear out prefix used by nginx in case it slips by, like on test
      @app.use '/api', (req, res, next) ->
        newUrl = req.originalUrl.substr 4
        res.redirect newUrl
      @app.use(cors())
      @app.use(@app.router)
      @app.enable('trust proxy')

    @app.configure 'development', =>
      @app.use(express.errorHandler())

    @app.configure 'test', =>
      @app.use(express.errorHandler())


  setupMongo: ->
    log.debug "Connecting to mongo #{Settings.mongoUrl}"
    mongoose.connect Settings.mongoUrl

  setupServers: ->
    #Set up http servers
    httpServer = http.createServer(@app)

    dementorController = new DementorController
    Logger.listen dementorController, 'dementorController'

    hangoutController = new HangoutController
    Logger.listen hangoutController, 'hangoutController'

    stripeController = new StripeController
    Logger.listen stripeController, 'stripeController'

    fileController = new FileController
    Logger.listen fileController, 'fileController'

    bolideClient = new BolideClient
    Logger.listen bolideClient, 'bolideClient'

    fileSyncer = new FileSyncer
    Logger.listen fileSyncer, 'fileSyncer'

    log.info  "Initializing azkaban"
    Azkaban.initialize
      httpServer: httpServer
      dementorController: dementorController
      hangoutController: hangoutController
      stripeController: stripeController
      fileController: fileController
      bolideClient: bolideClient
      fileSyncer: fileSyncer
      mongoose: mongoose
      apogeeLogProcessor: new ApogeeLogProcessor 1000 #interval to check metrics db

    @azkaban = Azkaban.instance()
    Logger.listen @azkaban, 'azkaban'

    require('./routes')(@app)
    
  shutdown: (returnVal=0) ->
    #Multiple ^C will allow exit in haste
    process.exit(returnVal || 1) if @SHUTTING_DOWN # || not ?, because we don't want 0
    @SHUTTING_DOWN = true
    process.on 'uncaughtException', (err) ->
      console.warn "Error in shutting down", err
      returnVal = returnVal || 1
    @azkaban.shutdownGracefully ->
      process.exit returnVal ? 0
    setTimeout ->
      console.error "Could not close connections in time, forcefully shutting down"
      process.exit returnVal || 1
    , 10*1000


  listen: (callback)->
    process.on 'SIGINT', =>
      @shutdown()

    process.on 'SIGTERM', =>
      @shutdown()

    unless process.env.MADEYE_TEST
      process.on 'uncaughtException', (err) =>
        console.error "Exiting because of uncaught exception: " + err
        if err.stack
          console.error err.stack
        console.error "Exiting because of uncaught exception: #{err.message}", error:err
        @shutdown(1)

    @azkaban.httpServer.listen @app.get('port'), =>
      log.info  "Express server listening on port " + @app.get('port')
      callback?()

    
server = new Server
module.exports = server
