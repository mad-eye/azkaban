express = require('express')
http = require('http')
io = require 'socket.io'
{Settings} = require 'madeye-common'
{DementorChannel} = require './src/dementorChannel'
{Azkaban} = require './src/azkaban'
FileController = require('./src/fileController')
BolideClient = require "./src/bolideClient"
ApogeeLogProcessor = require './src/apogeeLogProcessor'
DementorController = require('./src/dementorController')
HangoutController = require('./src/hangoutController')
DDPClient = require('./src/ddpClient')
{cors} = require 'madeye-common'
mongoose = require 'mongoose'
{logger} = require './src/logger'
FileSyncer = require './src/fileSyncer'

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
      @app.use(cors())
      @app.use(@app.router)

    @app.configure 'development', =>
      @app.use(express.errorHandler())

    @app.configure 'test', =>
      @app.use(express.errorHandler())


  setupMongo: ->
    logger.debug "Connecting to mongo #{Settings.mongoUrl}"
    mongoose.connect Settings.mongoUrl

  setupServers: ->
    #Set up http/socket servers
    httpServer = http.createServer(@app)

    socketServer = io.listen httpServer
    socketServer.configure ->
      socketServer.set 'log level', 2

    dementorChannel = new DementorChannel
    socketServer.sockets.on 'connection', (socket) =>
      dementorChannel.attach socket

    ddpUrl = "ws://#{Settings.apogeeDDPHost}/websocket"
    ddpClient = new DDPClient ddpUrl
    ddpClient.on 'ready', ->
      logger.debug "Connected to DDP server at #{ddpUrl}"
      
    logger.debug "initializing azkaban"
    Azkaban.initialize
      socketServer: socketServer
      httpServer: httpServer
      dementorChannel: dementorChannel
      dementorController: new DementorController
      hangoutController: new HangoutController
      fileController: new FileController
      bolideClient: new BolideClient
      mongoose: mongoose
      apogeeLogProcessor: new ApogeeLogProcessor 1000 #interval to check metrics db
      fileSyncer: new FileSyncer
      ddpClient: ddpClient

    @azkaban = Azkaban.instance()

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
      logger.error "Could not close connections in time, forcefully shutting down"
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
        logger.error "Exiting because of uncaught exception: #{err.message}", error:err
        @shutdown(1)

    @azkaban.httpServer.listen @app.get('port'), =>
      logger.debug "Express server listening on port " + @app.get('port')
      callback?()

    
server = new Server
module.exports = server
