{ServiceKeeper} = require '../ServiceKeeper'
{messageMaker, messageAction} = require 'madeye-common'

class DementorChannel
  constructor: () ->

  route : (message, callback) ->
    switch message.action
      when messageAction.ADD_FILES then @addFiles message, callback
      when messageAction.REMOVE_FILES  then @removeFiles message, callback
      else callback? new Error("Unknown action: " + message.action)

  addFiles : (message, callback) ->
    mongoConnection = ServiceKeeper.mongoInstance()
    mongoConnection.addFiles message.data.files, message.projectId, (err, results) ->
      if err
        console.error "Error in addFiles:", err
        callback? err 
      else
        console.log "Results from addFile:", results
        replyMessage = messageMaker.replyMessage message, results
        callback? null, replyMessage 

  removeFiles : (message, callback) ->
    console.log "Called removeFiles with ", message

exports.DementorChannel = DementorChannel
