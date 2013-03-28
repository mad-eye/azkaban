_ = require 'underscore'
_path = require 'path'
{File, Project, wrapDbError} = require './models'
{EventEmitter} = require 'events'
{logger} = require './logger'
async = require 'async'
{crc32} = require("madeye-common")

class FileSyncer extends EventEmitter


  #Add missing parent dirs to files
  #Modifies files, returns null
  completeParentFiles: (files) ->
    newFileMap = {}
    newFileMap[file.path] = file for file in files

    parentsMap = {}
    for file in files
      path = file.path
      loop
        path = _path.dirname path
        break if path == '.' or path == '/' or !path?
        if (path of parentsMap) or (path of newFileMap)
          break
        else
          parentsMap[path] = {path: path, projectId: file.projectId, isDir: true}

    for path, parent of parentsMap
      files.push parent unless newFileMap[path]


  # returns [newFiles, unmodifiedFiles, modifiedFiles, orphanedFiles]
  partitionFiles: (files, existingFiles) ->
    newFiles = []
    modifiedFiles = []
    unmodifiedFiles = []
    existingFileMap = {}; existingFileMap[file.path] = file for file in existingFiles

    for file in files
      if file.path of existingFileMap
        existingFile = existingFileMap[file.path]
        if existingFile.mtime < file.mtime
          logger.debug "File modified offline.",
            projectId: existingFile.projectId,
            fileId:existingFile._id,
            existingMtime: existingFile.mtime,
            newMtime: file.mtime
          _.extend existingFile, file
          modifiedFiles.push existingFile
        else
          unmodifiedFiles.push existingFile
        delete existingFileMap[file.path]
      else
        newFiles.push file

    orphanedFiles = _.values existingFileMap

    return [newFiles, unmodifiedFiles, modifiedFiles, orphanedFiles]

  #callback: (error, savedModifiedFiles) ->
  updateModifiedFiles: (modifiedFiles, callback) ->
    #filesToRefresh = _.filter modifiedFiles, (file) ->
      #file.lastOpened? && !file.modified
    #console.log "Found files to refresh:", filesToRefresh
    #async.parallel [
    async.each modifiedFiles, (file, cb) ->
      file.modified_locally = true if file.modified or file.lastOpened?
      file.save cb
    , callback
    #, async.each filesToRefresh, (file, cb) =>
        #@loadFile file.projectId, file._id, true, cb
    #], callback

  syncFiles : (files, projectId, deleteMissing=false, callback) ->
    if 'function' == typeof deleteMissing
      callback = deleteMissing
      deleteMissing = false

    unless projectId?
      return callback errors.new errorType.MISSING_PARAM, "No project id found for AddFiles", files:files

    files = files[..] #Prevent files mutation
    file.projectId = projectId for file in files
    @completeParentFiles files

    File.findByProjectId projectId, (err, existingFiles) =>
      if err then callback wrapDbError err; return

      [newFiles, unmodifiedFiles, modifiedFiles, orphanedFiles] = @partitionFiles files, existingFiles
      #console.log "Found unmodifiedFiles:", _.pluck(unmodifiedFiles, 'path')
      #console.log "Found modifiedFiles:", modifiedFiles
      
      #Save new files and return the project files
      File.create newFiles, (err) ->
        if err then callback wrapDbError err; return
        savedFiles = Array.prototype.slice.call arguments, 1
        filesToReturn = savedFiles.concat unmodifiedFiles, modifiedFiles
        callback null, filesToReturn

      @updateModifiedFiles modifiedFiles, (err) ->
        console.log "Returning from updateModifiedFiles"
        if err
          logger.error "Error updating modified files", projectId:projectId, error:err

      if deleteMissing
        if orphanedFiles.length > 0
          logger.debug "Deleting #{orphanedFiles.length} files", projectId:projectId
        for file in orphanedFiles
          file.remove (err) ->
            logger.error "Error deleting file",
              error: wrapDbError err
              projectId: projectId
              fileId: file._id
      
  _cleanupLineEndings = (contents) ->
    return contents unless /\r/.test contents
    lineBreakRegex = /(\r\n|\r|\n)/gm
    hasDos = /\r\n/.test contents
    hasUnix = /[^\r]\n/.test contents
    hasOldMac = /\r(?!\n)/.test contents
    if hasUnix
      contents.replace lineBreakRegex, '\n'
    else if hasDos and hasOldMac
      contents.replace lineBreakRegex, '\r\n'
    else
      contents

  #callback: (err, contents) ->
  loadFile: (projectId, fileId, reset, callback) ->
    @azkaban.dementorChannel.getFileContents projectId, fileId, (err, contents) =>
      logger.debug "Returned file from dementor", {hasError:err?, projectId:projectId, fileId:fileId}
      return callback err if err
      cleanContents = _cleanupLineEndings(contents)
      checksum = crc32 cleanContents if cleanContents?
      warning = null
      unless cleanContents == contents
        warning =
          title: "Inconsistent line endings"
          message: "We've converted them all into one type."
      if reset then logger.debug "Resetting file contents", {projectId:projectId, fileId:fileId}
      @azkaban.bolideClient.setDocumentContents fileId, cleanContents, reset, (err) =>
        callback err, checksum, warning
      File.update {_id:fileId}, {$set: {
        modified_locally: false
        lastOpened: Date.now()
        checksum: checksum
      }}, (err) ->
        logger.error "Error updating loaded file", {projectId, fileId, error:err} if err


module.exports = FileSyncer
