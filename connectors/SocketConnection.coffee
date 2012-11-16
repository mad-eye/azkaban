browserChannel = require('browserchannel').server
connect = require('connect')
uuid = require 'node-uuid'

class SocketConnection
  constructor: (@controller) ->

  confirmationMessage: (message) ->
    confirmationMsg =
      action: 'acknowlege',
      receivedId:message.uuid,
      timestamp: new Date().getTime(),
      uuid: uuid.v4()
    @socket.send confirmationMsg

  startup: (@socket) ->
    console.log "New socket: #{socket.id} from #{socket.address}"

    socket.on 'message', (message) =>
      @controller.route message, (err, result) ->
        if err
          socket.send {error: err.message}
        else
          socket.send result

      socket.send @confirmationMessage message

    socket.on 'close', (reason) =>
      console.log "Socket #{socket.id} disconnected (#{reason})"

  listen: (bcPort) ->
    @server = connect(
      browserChannel (socket) =>
        console.log "Found socket", socket
        @startup(socket)
    ).listen(bcPort)

    console.log 'Echo server listening on localhost:' + bcPort

exports.SocketConnection = SocketConnection
