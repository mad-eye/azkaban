events = require 'events'
{logger} = require './logger'

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
    @dementorChannel.destroy ->
      @httpServer.close ->
        @mongoose.disconnect ->
          callback?()

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
