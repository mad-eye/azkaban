browserChannel = require('browserchannel').server
connect = require('connect')
uuid = require 'node-uuid'

class SocketConnection
  constructor: (@controller) ->
    @liveSockets = {} # {projectId: socket}, to look sockets up for apogee-dementor communication
    @sidPidMap = {} # {socketId:projectId}, to look up entries in liveSockets for deletion

  listen: (bcPort) ->
    @server = connect(
      browserChannel (socket) =>
        console.log "Found socket", socket
        @connect(socket)
    ).listen(bcPort)
    console.log 'Echo server listening on localhost:' + bcPort

  confirmationMessage: (message) ->
    confirmationMsg =
      action: 'confirm',
      receivedId:message.uuid,
      timestamp: new Date().getTime(),
      uuid: uuid.v4()

  connect: (@socket) ->
    console.log "New socket: #{socket.id} from #{socket.address}"
    @liveSockets[socket.id] = socket

    socket.on 'message', (message) =>
      if message.action == 'handshake'
        @attachSocket socket, message.projectId
        return
      @controller.route message, (err, result) ->
        if err
          socket.send {error: err.message}
        else
          socket.send result

      socket.send @confirmationMessage message

    socket.on 'close', (reason) =>
      @detachSocket socket
      console.log "Socket #{socket.id} disconnected (#{reason})"

  attachSocket: (socket, projectId) ->
    @sidPidMap[socket.id] = projectId
    @liveSockets[projectId] = socket

  detachSocket: (socket) ->
    projectId = @sidPidMap[socket.id]
    delete @liveSockets[projectId] if projectId
    delete @sidPidMap[socket.id]

  
exports.SocketConnection = SocketConnection
