browserChannel = require('browserchannel').server
connect = require('connect')
app = require '../app'

route = (data, callback) ->
  switch data.action
    when 'init' then init data, callback
    when 'addFiles' then addfiles data, callback
    else callback new Error("Unknown action: " + data.action)

addFiles = (data, callback) ->
  console.log "Called addFiles with ", data
  callback(null, null)

removeFiles = (data, callback) ->
  console.log "Called removeFiles with ", data
  callback(null, null)

server = connect(
  browserChannel (session) ->
    console.log "New session: #{session.id} from #{session.address} with cookies #{session.headers.cookie}"

    session.on 'message', (data) ->
      console.log "#{session.id} sent #{JSON.stringify data}"
      route data, (err, result) ->
        if err
          session.send {error: err.message}
        else
          session.send result

      session.send data

    session.on 'close', (reason) ->
      console.log "Session #{session.id} disconnected (#{reason})"

).listen(app.get("bchannel.port"))

console.log 'Echo server listening on localhost:' + app.get("bchannel.port")
