{EventEmitter} = require 'events'
async = require 'async'

class Azkaban_ extends EventEmitter
  constructor: (services) ->
    for name, service of services
      @setService name, service

  setService: (name, service) ->
    @[name] = service
    service.azkaban = @

  shutdownGracefully: (callback) ->
    @emit 'debug', "Shutting down gracefully."
    async.parallel
      http: (cb) =>
        @httpServer.close =>
          @emit 'debug', "Http server shut down"
          cb()
      mongoose: (cb) =>
        @mongoose.disconnect =>
          @emit 'debug', "Mongoose shut down"
          cb()
    , callback

class Azkaban
  _instance = undefined

  @initialize: (services) ->
    _instance = new Azkaban_ services

  @instance: ->
    return _instance

  @reset: ->
    _instance = undefined

exports.Azkaban = Azkaban
