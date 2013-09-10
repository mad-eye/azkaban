_ = require 'underscore'
{Project, File, wrapDbError} = require './models'
{messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
async = require 'async'
{crc32} = require 'madeye-common'
FileSyncer = require './fileSyncer'
{EventEmitter} = require 'events'


class DementorChannel extends EventEmitter
  constructor: () ->
    @liveSockets = {}
    @socketProjectIds = {}
    @closeProjectTimers = {}

  shutdown: (callback) ->
    numSockets = _.keys(@liveSockets).length
    @emit 'debug', "Shutting down #{numSockets} sockets"
    return callback() if numSockets == 0
    shutdowns = []
    for projectId, socket of @liveSockets
      shutdowns.push (cb) =>
        socket.disconnect()
        @closeProject projectId, cb
    async.each shutdowns, (err) =>
      @emit 'trace', "Shut down all sockets"
      callback()

  handleError: (err, projectId, callback) ->
    @emit 'warn', "Error in dementorChannel", projectId: projectId, err
    callback err

  attach: (socket) ->
    socket.on 'disconnect', =>
      projectId = @socketProjectIds[socket.id]
      @emit 'debug', "Disconnecting socket #{socket.id}", projectId:projectId
      #Don't close the project if another connection is 'active'
      if projectId && @liveSockets[projectId] == socket
        @closeProjectTimers[projectId] = setTimeout (=>
          @closeProject projectId
        ), 5*1000


    #callback: (error) ->
    socket.on messageAction.HANDSHAKE, (projectId, callback) =>
      @emit 'debug', "Received handshake", projectId:projectId
      @liveSockets[projectId] = socket
      @socketProjectIds[socket.id] = projectId
      @openProject projectId, (err) ->
        callback? err

    #NB: This will modify data.files, converting it to an array if approprate.
    #returns an error if data has a problem
    validateData = (data) ->
      error = null
      unless data.files?
        error = errors.new errorType.MISSING_PARAM, param:'files', value:data.files
      else unless _.isObject data
        error = errors.new errorType.INVALID_PARAM, param:'files', value:data.files
      else if not _.isArray data.files
        #is this a single object?
        if data.files.path?
          data.files = [data.files]
        else
          error = errors.new errorType.INVALID_PARAM, param:'files', value:data.files
      return error

    #callback: (error, files) ->
    socket.on messageAction.LOCAL_FILES_ADDED, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      data.projectId ?= projectId
      @emit 'debug', "Adding remote files", projectId:data.projectId
      error = validateData data
      if error
        @emit 'warn', "Bad data in LOCAL_FILES_ADDED", {projectId, data, error}
        return callback error
      @azkaban.fileSyncer.syncFiles data.files, data.projectId, (err, files) =>
        if err then callback wrapDbError err; return
        args = ['files']
        args.push f._id for f in files when f
        @azkaban.ddpClient.invokeMethod 'markDirty', args unless err

        callback null, files

    #callback: (error) ->
    socket.on messageAction.LOCAL_FILE_SAVED, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      projectId ?= data.projectId
      unless data?.file?._id
        error = errors.new errorType.INVALID_PARAM, param:'file', value:data.file
        @emit 'warn', "Bad data in LOCAL_FILES_SAVED", {projectId, data, error}
        return callback error
      #TODO: Also accept paths if there is no _id
      File.findById data.file._id, (err, file) =>
        return @handleError wrapDbError(err), projectId, callback if err
        return @handleError errors.new(errorType.NO_FILE), projectId, callback unless file
        @emit 'debug', "Saving remote file", projectId:projectId, fileId: data.file._id, fileModified:file.modified
        return callback null, null unless file.lastOpened?
        checksum = crc32 data.contents
        return callback null, null if file.checksum? and checksum == file.checksum
        if file.modified
          file.update {$set: {modified_locally:true, checksum}}, (err) =>
            @azkaban.ddpClient.invokeMethod 'markDirty', ['files', file._id] unless err
            callback err, {
              action : messageAction.WARNING
              message : "The file #{file.path} was modified on MadEye; if it is saved there, it will be overwritten here."
            }
        else
          file.update {$set: {checksum}}, (err) =>
            @azkaban.ddpClient.invokeMethod 'markDirty', ['files', file._id] unless err
          @azkaban.bolideClient.setDocumentContents file._id, data.contents, true, (err) =>
            return @handleError err, projectId, callback if err
            callback null
        

    #callback: (error) ->
    socket.on messageAction.LOCAL_FILES_REMOVED, (data, callback) =>
      projectId = @socketProjectIds[socket.id]
      projectId ?= data.projectId
      @emit 'debug', "Removing remote files", projectId: projectId, files: data.files
      error = validateData data
      if error
        @emit 'warn', "Bad data in LOCAL_FILES_REMOVED", {projectId, data, error}
        return callback error

      message = null
      async.each data.files, (f, cb) =>
        unless f?._id
          return cb error = errors.new errorType.INVALID_PARAM, param:'file', value:f
        File.findById f._id, (err, file) =>
          return @handleError wrapDbError(err), projectId, cb if err
          return @handleError errors.new(errorType.NO_FILE), projectId, cb unless file
          unless file.modified
            file.remove cb
          else
            @emit 'debug', "Removing modified file", projectId:projectId, fileId:file._id, path:file.path
            message ?= ''
            message += "The file #{file.path} is modified by others.  If they save it, it will be recreated.\n"
            file.update {$set: {removed:true}}, cb
      , (err) =>
        if err then callback? err; return
        response = null
        if message
          response =
            action: messageAction.WARNING
            message: message
        callback? null, response
        args = ['files']
        args.push f._id for f in data.files when f
        @azkaban.ddpClient.invokeMethod 'markDirty', args

  #####
  # Helper methods

  #callback: (err) ->
  openProject : (projectId, callback) ->
    @emit 'debug', "Opening project", {projectId:projectId}
    clearTimeout @closeProjectTimers[projectId]
    @closeProjectTimers[projectId] = null
    Project.update {_id:projectId}, {closed:false}, (err) =>
      return callback?(err) if err
      @azkaban.ddpClient.invokeMethod 'markDirty', ['projects', projectId]
      callback?()

  closeProject : (projectId, callback) ->
    @emit 'debug', "Closing project", {projectId:projectId}
    Project.findById projectId, (err, project)=>
      return callback("PROJECT NOT FOUND") unless project
      project.tunnels = null
      project.closed = true
      project.save callback

#####
# Methods for Azkaban to call to give Dementor orders

  #callback: (err) ->
  saveFile: (projectId, fileId, contents, callback) ->
    @emit 'debug', "Saving local file", {fileId:fileId, projectId:projectId}
    socket = @liveSockets[projectId]
    unless socket?
      callback errors.new errorType.CONNECTION_CLOSED
      return
    socket.emit messageAction.SAVE_LOCAL_FILE, {fileId:fileId, contents:contents}, callback

  #callback: (err, contents) ->
  getFileContents: (projectId, fileId, callback) ->
    @emit 'debug', "Getting local file contents", {fileId:fileId, projectId:projectId}
    socket = @liveSockets[projectId]
    unless socket?
      callback errors.new errorType.CONNECTION_CLOSED
      return
    socket.emit messageAction.REQUEST_FILE, {fileId:fileId}, callback

exports.DementorChannel = DementorChannel
