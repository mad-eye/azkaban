_ = require 'underscore'
_path = require 'path'
{File, Project, wrapDbError} = require './models'
{EventEmitter} = require 'events'
{logger} = require './logger'
async = require 'async'

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
    filesToRefresh = _.filter modifiedFiles, (file) ->
      file.lastOpened? && !file.modified
    async.parallel [
      async.each modifiedFiles, (file, cb) ->
        file.modified_locally = true if file.modified
        file.save cb
    , async.each filesToRefresh, (file, cb) ->
      console.log "TODO: load contents of filesToRefresh"
    ], callback

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
      
      #Save new files and return the project files
      File.create newFiles, (err) ->
        if err then callback wrapDbError err; return
        savedFiles = Array.prototype.slice.call arguments, 1
        filesToReturn = savedFiles.concat unmodifiedFiles, modifiedFiles
        callback null, filesToReturn

      @updateModifiedFiles modifiedFiles
      if deleteMissing
        for file in orphanedFiles
          file.remove (err) ->
            logger.error "Error deleting file",
              error: wrapDbError err
              projectId: projectId
              fileId: file._id
      
      
module.exports = FileSyncer
