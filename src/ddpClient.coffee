events = require 'events'
uuid = require 'node-uuid'
_ = require 'underscore'
Ddp = require "ddp"
{logger} = require './logger'
{errors, errorType} = require 'madeye-common'

DEFAULT_OPTIONS =
  host: "localhost",
  port: 3000,
  auto_reconnect: true,
  auto_reconnect_timer: 500

wrapSocketError = (err) ->
  return err unless err
  return err if err.madeye
  return errors.new errorType.SOCKET_ERROR, err

class DDPClient extends events.EventEmitter
  constructor: (options) ->
    options = _.extend DEFAULT_OPTIONS, options
    @emit 'debug', "Initializing DDPClient with options", options
    @ddpClient = new Ddp options
    @initialized = false

  shutdown: (callback) ->
    @emit 'trace', 'Shutting down'
    @ddpClient?.close()
    process.nextTick callback if callback

  connect: (callback) ->
    @ddpClient.connect (error) =>
      @emit 'error', error if error
      @emit 'debug', "DDP connected" unless error
      @_initialize()
      callback?(wrapSocketError error)

  _initialize: ->
    return if @initialized
    @initialized = true
    @ddpClient.on 'message', (msg) =>
      @emit 'trace', 'Ddp message: ' + msg
    @ddpClient.on 'socket-close', (code, message) =>
      @emit 'debug', "DDP closed: [#{code}] #{message}"
    @ddpClient.on 'socket-error', (error) =>
      @emit 'error', error
    
  subscribe: (collectionName, args...) ->
    @ddpClient.subscribe collectionName, args, =>
      @emit 'trace', "Subscribed to #{collectionName}"

  #callback(err, result)
  invokeMethod: (method, params, callback) ->
    @emit 'trace', "Invoking #{method} with params:", params
    @ddpClient.call method, params, (err, result) =>
      callback? err, result
      @emit 'trace', "#{method} returned #{result}"

module.exports = DDPClient
