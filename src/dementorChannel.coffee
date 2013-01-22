{DataCenter} = require './dataCenter'
{messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'

class DementorChannel
  constructor: () ->
    @liveSockets = {}
    @socketProjectIds = {}

  destroy: (callback) ->
    for projectId, socket in @liveSockets
      socket.disconnect()
      @closeProject projectId
      callback?()

  attach: (socket) ->
    socket.on 'disconnect', =>
      projectId = @socketProjectIds[socket.id]
      #Don't close the project if another connection is 'active'
      if projectId && @liveSockets[projectId] == socket
        @closeProject projectId


    #callback: (error) ->
    socket.on messageAction.HANDSHAKE, (projectId, callback) =>
      console.log "Received handshake for projectId", projectId
      @liveSockets[projectId] = socket
      @socketProjectIds[socket.id] = projectId
      callback?()

    #callback: (error, files) ->
    socket.on messageAction.ADD_FILES, (data, callback) =>
      dataCenter = new DataCenter
      dataCenter.addFiles data.files, data.projectId, callback

    #callback: (error) ->
    socket.on messageAction.SAVE_FILE, (data, callback) =>
      console.log "Called saveFile for ", data.fileId

    #callback: (error) ->
    socket.on messageAction.REMOVE_FILES, (data, callback) =>
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
