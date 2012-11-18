{ServiceKeeper} = require '../ServiceKeeper'
class DementorChannel
  constructor: () ->

  route : (message, callback) ->
    switch message.action
      when 'addFiles' then @addFiles message
      when 'removeFiles' then @removeFiles message
      else @callback? new Error("Unknown action: " + message.action)

  addFiles : (message, callback) ->
    mongoConnection = ServiceKeeper.mongoInstance()
    mongoConnection.addFiles message.data.files, message.projectId, (err, results) ->
      if err
        console.error "Error in addFiles:", err
        callback(err) if callback
      else
        console.log "Results from addFile:", results
        #callback(null, results) if callback

  removeFiles : (message, callback) ->
    console.log "Called removeFiles with ", data

exports.DementorChannel = DementorChannel
