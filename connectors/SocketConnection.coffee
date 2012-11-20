browserChannel = require('browserchannel').server
connect = require('connect')
uuid = require 'node-uuid'

class SocketConnection
  constructor: (@controller) ->
    @liveSockets = {} # {projectId: socket}, to look sockets up for apogee-dementor communication
    @projectIdMap = {} # {socketId:projectId}, to look up entries in liveSockets for deletion
    @sentMessages = []
    @registeredCallbacks = {}

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

    socket.on 'message', (message) =>
      if message.action == 'handshake'
        @attachSocket socket, message.projectId
        return
      else if message.action == 'confirm'
        delete @sentMessages[message.receivedId]
        return
      #Check for any callbacks waiting for a response.
      if message.replyTo?
        #console.log "Invoking registered callback to #{message.replyTo}"
        callback = @registeredCallbacks[message.replyTo]
        if callback
          if message.error
            callback {error: message.error}
          else
            callback null, message
        return
        #TODO: Should this be the end of the message?  Do we ever need to route replies?
      @controller.route message, (err, result) ->
        if err
          @send socket, {error: err.message}
        else
          @send socket, result

      @send socket, @confirmationMessage message

    socket.on 'close', (reason) =>
      @detachSocket socket
      console.log "Socket #{socket.id} disconnected (#{reason})"

  attachSocket: (socket, projectId) ->
    @projectIdMap[socket.id] = projectId
    @liveSockets[projectId] = socket

  detachSocket: (socket) ->
    projectId = @projectIdMap[socket.id]
    delete @liveSockets[projectId] if projectId
    delete @projectIdMap[socket.id]

  send: (socket, message, carefully=false) ->
    message.uuid = uuid.v4()
    message.timestamp = new Date().getTime()
    socket.send message
    if carefully
      @sentMsgs[message.uuid] = message
    return message.uuid

    
  #callback = (err, data) ->, 
  tell: (projectId, message, callback) ->
    #console.log "Sending message to #{projectId}:", message
    socket = @liveSockets[projectId]
    unless socket
      callback({error: 'The project has been closed.'}) if callback
      return
    messageId = @send socket, message
    @registeredCallbacks[messageId] = callback

  
exports.SocketConnection = SocketConnection
