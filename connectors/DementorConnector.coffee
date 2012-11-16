browserChannel = require('browserchannel').server
connect = require('connect')

class DementorRoutes
  constructor: (@callback) ->

  route : (message) ->
    switch message.action
      when 'addFiles' then @addFiles message.data
      when 'removeFiles' then @removeFiles message.data
      else @callback? new Error("Unknown action: " + message.action)

  addFiles : (data) ->
    console.log "Called addFiles with ", data
    @callback? null, data

  removeFiles : (data) ->
    console.log "Called removeFiles with ", data
    @callback? null, data

exports.DementorRoutes = DementorRoutes

class SocketConnection
  constructor: (@controller) ->

  startup: (@socket) ->
    console.log "New socket: #{socket.id} from #{socket.address} with cookies #{socket.headers.cookie}"

    socket.on 'message', (message) =>
      console.log "#{socket.id} sent #{JSON.stringify message}"
      @controller.route message, (err, result) ->
        if err
          socket.send {error: err.message}
        else
          socket.send result

      socket.send message

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
