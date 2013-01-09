{ServiceKeeper} = require '../ServiceKeeper'
{DataCenter} = require './dataCenter'
{messageMaker, messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'

class DementorChannel
  constructor: () ->

  route : (message, callback) ->
    switch message.action
      when messageAction.ADD_FILES then @addFiles message, callback
      when messageAction.REMOVE_FILES  then @removeFiles message, callback
      when messageAction.REPLY then "registered callback should have handled this."
      else callback? errors.new errorType.UNKNOWN_ACTION, {action: message.action}

  addFiles : (message, callback) ->
    dataCenter = new DataCenter
    dataCenter.addFiles message.data.files, message.projectId, (err, results) ->
      if err
        console.error "Error in addFiles:", err
        callback? err
      else
        #console.log "Results from addFile:", results
        replyMessage = messageMaker.replyMessage message, files: results
        callback? null, replyMessage

  removeFiles : (message, callback) ->
    console.log "Called removeFiles with ", message

  closeProject : (projectId) ->
    dataCenter = new DataCenter
    dataCenter.closeProject projectId, (err) ->
      if err
        console.error "Error in closing project #{projectId}:", err


exports.DementorChannel = DementorChannel
