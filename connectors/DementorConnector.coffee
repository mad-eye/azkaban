browserChannel = require('browserchannel').server
connect = require('connect')
{Settings} = require '../Settings'

class DementorController
  constructor: ->

  route = (message, callback) ->
    switch message.action
      when 'init' then @dementorController.init message.data, callback
      when 'addFiles' then @dementorController.addfiles message.data, callback
      else callback new Error("Unknown action: " + message.action)

  addFiles = (data, callback) ->
    console.log "Called addFiles with ", data
    callback(null, null)

  removeFiles = (data, callback) ->
    console.log "Called removeFiles with ", data
    callback(null, null)

exports.DementorController = DementorController

class DementorConnection
  constructor: (@dementorController) ->

  initialize: (bcPort) ->
    @server = connect(
      browserChannel (socket) =>
        @socket = socket
        console.log "New socket: #{socket.id} from #{socket.address} with cookies #{socket.headers.cookie}"

        socket.on 'message', (message) =>
          console.log "#{socket.id} sent #{JSON.stringify message}"
          @dementorController.route message, (err, result) ->
            if err
              socket.send {error: err.message}
            else
              socket.send result

          socket.send message

        socket.on 'close', (reason) =>
          console.log "Socket #{socket.id} disconnected (#{reason})"

    ).listen(bcPort)

    console.log 'Echo server listening on localhost:' + bcPort

exports.DementorConnection = DementorConnection
