events = require 'events'
uuid = require 'node-uuid'
WebSocket = require "ws"
{logger} = require './logger'
{errors, errorType} = require 'madeye-common'

class DDPClient extends events.EventEmitter
  constructor: (url) ->
    #TODO think about whehter we need a pool of connections here
    @ready = false
    @callbacks = {}
    @ws = new WebSocket url
    @activateSocket()

  shutdown: ->
    @ws?.close()

  wrapSocketError : (err) ->
    return err unless err
    return err if err.madeye
    if err.message == 'not open'
      @ready = false
    return errors.new errorType.SOCKET_ERROR


  sendMessage: (obj, callback)->
    obj.id = uuid.v4()
    @ws.send JSON.stringify(obj), (err) =>
      if err
        console.log "Error sending message", obj, err
        err = @wrapSocketError err
        if callback
          return callback err
        else
          logger.error "Error sending message", message:obj, error:err
      @callbacks[obj.id] = callback

  activateSocket: ->
    @ws.on "open", =>
      @sendMessage {msg: "connect", version: "pre1", support: "pre1"}, (err) =>
        @emit 'error', err if err

    @ws.on "message", (message) =>
      response = JSON.parse(message)
      #Sometimes an initial empty message is sent.  We should ignore.
      return unless response.msg
      switch response.msg
        when "connected"
          #message received during initial handshake
          @ready = true
          @emit 'ready'
        when 'failed'
          #TODO: Make this a MadEye error
          errorMessage = "Failed to connect to DDP server.  It suggests using version " + response.version
          err = {type:"DDP_FAILED", message:errorMessage, version:response.version}
          @emit 'error', err
        when 'result'
          @callbacks[response.id]?(null, response.result)
        when 'updated'
          #this is sent after markDirty.  ignore
        else
          #Should get this, ignore but log
          logger.info "Got unexpected message from DDP server: #{message}", message: response

  #callback(err)
  invokeMethod: (method, params, callback) ->
    return callback? 'not ready' unless @ready
    @sendMessage {msg: "method", params: params, method: method}, callback

module.exports = DDPClient
