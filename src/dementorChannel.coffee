{Project, File, wrapDbError} = require './models'
{messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
{logger} = require './logger'
{dementorLogger} = require './logger'
async = require 'async'

class DementorChannel
  constructor: () ->
    @liveSockets = {}
    @socketProjectIds = {}
    @closeProjectTimers = {}

  destroy: (callback) ->
    for projectId, socket in @liveSockets
      socket.disconnect()
      @closeProject projectId
      callback?()

  handleError: (err, projectId, callback) ->
    logger.error "Error in dementorChannel", projectId: projectId, err
    callback err

  attach: (socket) ->
    socket.on 'disconnect', =>
      projectId = @socketProjectIds[socket.id]
      logger.debug "Disconnecting socket #{socket.id}", projectId:projectId
      #Don't close the project if another connection is 'active'
      if projectId && @liveSockets[projectId] == socket
        @closeProjectTimers[projectId] = setTimeout (=>
          @closeProject projectId
        ), 5*1000


    #callback: (error) ->
    socket.on messageAction.HANDSHAKE, (projectId, callback) =>
      logger.debug "Received handshake", projectId:projectId
      @liveSockets[projectId] = socket
      @socketProjectIds[socket.id] = projectId
      @openProject projectId, (err) ->
        callback? err

    #callback: (error, files) ->
    socket.on messageAction.LOCAL_FILES_ADDED, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      logger.debug "Adding remote files", projectId:projectId
      File.addFiles data.files, data.projectId, (err, files) ->
        if err then callback wrapDbError err; return
        callback null, files

    #callback: (error) ->
    socket.on messageAction.LOCAL_FILE_SAVED, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      File.findById data.file._id, (err, file) =>
        return @handleError wrapDbError err, projectId, callback if err
        logger.debug "Saving remote file", projectId:projectId, fileId: data.file._id, fileModified:file.modified
        if file.modified
          file.update {$set: {modified_locally:true}}, (err) ->
            callback err, {
              action : messageAction.WARNING
              message : "The file #{file.path} was modified by other; if they save it, it will be overwritten."
            }
        else
          @azkaban.bolideClient.setDocumentContents file._id, data.contents, true, (err) =>
            return @handleError err, projectId, callback if err
            callback null
        

    #callback: (error) ->
    socket.on messageAction.LOCAL_FILES_REMOVED, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      logger.debug "Removing remote files", projectId:projectId, files: data.files
      message = null
      async.each data.files, (f, cb) ->
        File.findById f._id, (err, file) ->
          return cb err if err
          unless file.modified
            file.remove cb
          else
            logger.debug "Removing modified file", projectId:projectId, fileId:file._id
            message ?= ''
            message += "The file #{file.path} is modified by others.  If they save it, it will be recreated.\n"
            file.update {$set: {removed:true}}, cb
      , (err) ->
        if err then callback err; return
        response = null
        if message
          response =
            action: messageAction.WARNING
            message: message
        callback null, response

    #callback: (error) ->
    socket.on messageAction.METRIC, (data, callback) =>
      data.projectId ?= @socketProjectIds[socket.id]
      level = data.level; delete data.level
      message = data.message; delete data.message
      dementorLogger.log level, message, data
      callback?()


  #####
  # Helper methods

  #callback: (err) ->
  openProject : (projectId, callback) ->
    logger.debug "Opening project", {projectId:projectId}
    clearTimeout @closeProjectTimers[projectId]
    @closeProjectTimers[projectId] = null
    Project.update {_id:projectId}, {closed:false}, (err) ->
      callback? err

  #callback: (err) ->
  closeProject : (projectId, callback) ->
    logger.debug "Closing project", {projectId:projectId}
    Project.update {_id:projectId}, {closed:true}, (err) ->
      callback? err


  #####
  # Methods for Azkaban to call to give Dementor orders

  #callback: (err) ->
  saveFile: (projectId, fileId, contents, callback) ->
    logger.debug "Saving local file", {fileId:fileId, projectId:projectId}
    socket = @liveSockets[projectId]
    unless socket?
      callback errors.new errorType.CONNECTION_CLOSED
      return
    socket.emit messageAction.SAVE_LOCAL_FILE, {fileId:fileId, contents:contents}, callback

  #callback: (err, contents) ->
  getFileContents: (projectId, fileId, callback) ->
    logger.debug "Getting local file contents", {fileId:fileId, projectId:projectId}
    socket = @liveSockets[projectId]
    unless socket?
      callback errors.new errorType.CONNECTION_CLOSED
      return
    socket.emit messageAction.REQUEST_FILE, {fileId:fileId}, callback

exports.DementorChannel = DementorChannel
