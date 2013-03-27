#TODO
#should probably turn this into a singleton to ensure that multiple web sockets aren't created
#should onReady be exported?


uuid = require 'node-uuid'
{Settings} = require "madeye-common"
WebSocket = require "ws"

#TODO think about whehter we need a pool of connections here
ready = false
callbacks = {}

console.log Settings.apogeeHost, Settings.apogeePort
ws = new WebSocket "ws://#{Settings.apogeeHost}:#{Settings.apogeePort}/websocket"

onReady = ->

sendMessage = (obj, callback)->
  obj.id = uuid.v4()
  ws.send JSON.stringify(obj)
  callbacks[obj.id] = callback

ws.on "open", ->
  sendMessage {msg: "connect", version: "pre1", support: "pre1"}

ws.on "message", (message) ->
  response = JSON.parse(message)
  console.log response
  #message received during initial handshake
  if response.msg == "connected"
    ready = true
    console.log "CONNECTED"
    onReady()
  else
    callbacks[response.id]?(null, response.result)

#callback(err)
invokeMethod = (method, params, callback) ->
#  callback "not ready" unless ready      
  sendMessage {msg: "method", params: params, method: method}, callback

exports.invokeMethod = invokeMethod
exports.onReady = invokeMethod

onReady = ->
  invokeMethod "getFileCount", [4], (err, result)->
    console.log "RESULT", result
