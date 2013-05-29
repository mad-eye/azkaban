events = require 'events'
{logger} = require './logger'
async = require 'async'

class Azkaban_ extends events.EventEmitter
  constructor: (services) ->
    for name, service of services
      @setService name, service
    #@setup()

  setService: (name, service) ->
    @[name] = service
    service.azkaban = @

  setup: ->
    @socketServer.sockets.on 'connection', (socket) =>
      @dementorChannel.attach socket
    @socketServer.configure =>
      @socketServer.set 'log level', 2

  

  shutdownGracefully: (callback) ->
    logger.debug "Shutting down gracefully."
    @ddpClient.shutdown()
    async.parallel
      http: (cb) =>
        @httpServer.close ->
          logger.debug "Http server shut down"
          cb()
      mongoose: (cb) =>
        @mongoose.disconnect ->
          logger.debug "Mongoose shut down"
          cb()
      dementor: (cb) =>
        @dementorChannel.shutdown ->
          logger.debug "DementorChannel shut down"
          cb()
    , callback

class Azkaban
  _instance = undefined

  @initialize: (services) ->
    _instance = new Azkaban_ services

  @instance: ->
    return _instance

  @reset: ->
    #console.log "Resetting Azkaban"
    _instance = undefined

exports.Azkaban = Azkaban
