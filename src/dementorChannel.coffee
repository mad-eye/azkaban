{Project, File, wrapDbError} = require './models'
{messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
{logger} = require './logger'

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
    logger.debug "Attaching socket #{socket.id}"

    socket.on 'disconnect', =>
      projectId = @socketProjectIds[socket.id]
      logger.debug "Disconnecting socket #{socket.id}", projectId:projectId
      #Don't close the project if another connection is 'active'
      if projectId && @liveSockets[projectId] == socket
        @closeProject projectId


    #callback: (error) ->
    socket.on messageAction.HANDSHAKE, (projectId, callback) =>
      logger.debug "Received handshake", projectId:projectId
      @liveSockets[projectId] = socket
      @socketProjectIds[socket.id] = projectId
      callback?()

    #callback: (error, files) ->
    socket.on messageAction.ADD_FILES, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      logger.debug "Adding remote files", projectId:projectId
      File.addFiles data.files, data.projectId, (err, files) ->
        if err then callback wrapDbError err; return
        callback null, files

    #callback: (error) ->
    socket.on messageAction.SAVE_FILE, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      logger.debug "Saving remote files", projectId:projectId

    #callback: (error) ->
    socket.on messageAction.REMOVE_FILES, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      logger.debug "Removing remote files", projectId:projectId

  #callback: (err) ->
  closeProject : (projectId, callback) ->
    logger.debug "Closing project #{projectId}"
    Project.update {_id:projectId}, {closed:true}, (err) ->
      callback? err


  # Methods for Azkaban to call to give Dementor orders
  #callback: (err) ->
  saveFile: (projectId, fileId, contents, callback) ->
    logger.debug "Saving local file", {fileId:fileId, projectId:projectId}
    socket = @liveSockets[projectId]
    unless socket?
      callback errors.new errorType.CONNECTION_CLOSED
      return
    socket.emit messageAction.SAVE_FILE, {fileId:fileId, contents:contents}, callback

  #callback: (err, contents) ->
  getFileContents: (projectId, fileId, callback) ->
    logger.debug "Getting local file contents", {fileId:fileId, projectId:projectId}
    socket = @liveSockets[projectId]
    unless socket?
      callback errors.new errorType.CONNECTION_CLOSED
      return
    socket.emit messageAction.REQUEST_FILE, {fileId:fileId}, callback

exports.DementorChannel = DementorChannel
