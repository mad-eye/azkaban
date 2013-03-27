_ = require 'underscore'
_path = require 'path'
{File, Project, wrapDbError} = require './models'
{EventEmitter} = require 'events'
{logger} = require './logger'

class FileSyncer extends EventEmitter


  pruneFiles: (wantedFiles, projectId) ->
      

  syncFiles : (files, projectId, deleteMissing=false, callback) ->
    if 'function' == typeof deleteMissing
      callback = deleteMissing
      deleteMissing = false
    
    unless projectId?
      return callback errors.new errorType.MISSING_PARAM, "No project id found for AddFiles", files:files
    
    files = files[..] #Prevent files mutation
    newFileMap = {}
    newFileMap[file.path] = file for file in files
    
    #add any parent directories that are missing
    parentsMap = {}
    for file in files
      path = file.path
    
    loop
      path = _path.dirname path
      break if path == '.' or path == '/' or !path?
      if (path of parentsMap) or (path of newFileMap)
        break
      else
        parentsMap[path] = {path: path, projectId: projectId, isDir: true}
    
    for path, parent of parentsMap
      files.push parent unless newFileMap[path]
    
    File.findByProjectId projectId, (err, existingFiles) ->
      if err then callback wrapDbError err; return
    
      filesToReturn = []
      filesToSave = []
      existingFileMap = {}
      existingFileMap[file.path] = file for file in existingFiles
      try
        for file in files
          if file.path of existingFileMap
            existingFile = existingFileMap[file.path]
            unless existingFile.mtime? and existingFile.mtime >= file.mtime
              _.extend existingFile, file
              if existingFile.lastOpened?
                existingFile.modified_locally = true
                existingFile.modified = true
                logger.debug "File modified offline.", projectId: projectId, fileId:existingFile._id, existingMtime: existingFile.mtime, newMtime: file.mtime
              existingFile.save()
            filesToReturn.push existingFile
            delete existingFileMap[file.path]
          else
            file.projectId = projectId
            newFile = new File file
            filesToSave.push newFile
      
    
        #Specifying 'File' is a little dangerous, but @ returns a Promise, not a true Model object.
        File.create filesToSave, (err) ->
          if err then callback wrapDbError err; return
          savedFiles = Array.prototype.slice.call arguments, 1
          filesToReturn = filesToReturn.concat savedFiles
          unless deleteMissing
            callback null, filesToReturn
          else
            filesToDelete = []
            filesToDelete.push file for path, file of existingFileMap
            async.each filesToDelete, ((file, cb) ->
              file.remove cb
            ), (err) ->
              if err then callback wrapDbError err; return
              callback null, filesToReturn
      catch err
        return callback wrapDbError err
    
module.exports = FileSyncer