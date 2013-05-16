events = require 'events'
uuid = require 'node-uuid'
WebSocket = require "ws"
{logger} = require './logger'

#TODO
#should probably turn this into a singleton to ensure that multiple web sockets aren't created
#should onReady be exported?

class DDPClient extends events.EventEmitter
  constructor: (url) ->
    #TODO think about whehter we need a pool of connections here
    @ready = false
    @callbacks = {}
    @ws = new WebSocket url
    @activateSocket()

  shutdown: ->
    @ws?.close()

  sendMessage: (obj, callback)->
    obj.id = uuid.v4()
    @ws.send JSON.stringify(obj)
    @callbacks[obj.id] = callback

  activateSocket: ->
    @ws.on "open", =>
      @sendMessage {msg: "connect", version: "pre1", support: "pre1"}

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
    return callback 'not ready' unless @ready
    @sendMessage {msg: "method", params: params, method: method}, callback

module.exports = DDPClient
