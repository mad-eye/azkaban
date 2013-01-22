{DataCenter} = require './dataCenter'
{messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'

class DementorChannel
  constructor: () ->
    @liveSockets = {}

  destroy: (callback) ->
    for projectId, socket in @liveSockets
      socket.disconnect()
      @closeProject projectId
      callback?()

  attach: (socket) ->
    socket.on 'disconnect', =>
      socket.get 'projectId', (projectId) =>
        #Don't close the project if another connection is 'active'
        return unless projectId && @liveSockets[projectId] == socket
        @closeProject projectId


    #callback: (error) ->
    socket.on messageAction.HANDSHAKE, (projectId, callback) =>
      @liveSockets[projectId] = socket
      socket.set 'projectId', projectId, ->
        callback?()

    #callback: (error, files) ->
    socket.on messageAction.ADD_FILES, (projectId, files, callback) =>
      dataCenter = new DataCenter
      dataCenter.addFiles files, projectId, callback

    #callback: (error) ->
    socket.on messageAction.SAVE_FILE, (fileId, contents, callback) =>
      console.log "Called saveFile for ", fileId

    #callback: (error) ->
    socket.on messageAction.REMOVE_FILES, (files, callback) =>
      console.log "Called removeFiles with ", files

  closeProject : (projectId) ->
    dataCenter = new DataCenter
    dataCenter.closeProject projectId, (err) ->
      if err
        console.error "Error in closing project #{projectId}:", err

  # Methods for Azkaban to call to give Dementor orders
  #callback: (err) ->
  saveFile: (projectId, fileId, contents, callback) ->
    socket = @liveSockets[projectId]
    unless socket?
      callback errors.new errorType.CONNECTION_CLOSED
      return
    socket.emit messageAction.SAVE_FILE, {fileId:fileId, contents:contents}, callback

  #callback: (err, contents) ->
  getFileContents: (projectId, fileId, callback) ->
    socket = @liveSockets[projectId]
    unless socket?
      callback errors.new errorType.CONNECTION_CLOSED
      return
    socket.emit messageAction.REQUEST_FILE, {fileId:fileId}, callback

exports.DementorChannel = DementorChannel
