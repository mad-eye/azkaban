_ = require 'underscore'
_path = require 'path'
{File, Project, wrapDbError} = require './models'
{EventEmitter} = require 'events'
async = require 'async'
{crc32} = require("madeye-common")
{normalizePath} = require("madeye-common")
{Settings} = require 'madeye-common'
fs = require "fs"

class FileSyncer extends EventEmitter

  cleanupFiles: (files, projectId) ->
    cleanFiles = []
    for file in files
      unless file
        @emit 'warn', "Null file found in cleanupFiles", files:files
        continue
      file.projectId = projectId
      file.orderingPath = normalizePath file.path
      cleanFiles.push file
    return cleanFiles
    
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
          @emit 'debug', "File modified offline.",
            projectId: existingFile.projectId,
            path: existingFile.path,
            fileId: existingFile._id,
            existingMtime: existingFile.mtime,
            newMtime: file.mtime
          existingFile = _.extend existingFile, file
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
    #async.parallel [
    async.each modifiedFiles, (file, cb) ->
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

    files = @cleanupFiles files, projectId

    File.findByProjectId projectId, (err, existingFiles) =>
      if err then callback wrapDbError err; return

      [newFiles, unmodifiedFiles, modifiedFiles, orphanedFiles] = @partitionFiles files, existingFiles
      #console.log "Found unmodifiedFiles:", unmodifiedFiles
      #console.log "Found modifiedFiles:", _.pluck(modifiedFiles, 'path')
      
      #Save new files and return the project files
      File.create newFiles, (err) ->
        if err then callback wrapDbError err; return
        savedFiles = Array.prototype.slice.call arguments, 1
        filesToReturn = savedFiles.concat unmodifiedFiles, modifiedFiles
        callback null, filesToReturn

      @updateModifiedFiles modifiedFiles, (err) =>
        if err
          @emit 'warn', "Error updating modified files", projectId:projectId, error:err

      if deleteMissing
        if orphanedFiles.length > 0
          @emit 'debug', "Deleting #{orphanedFiles.length} files", projectId:projectId
        for file in orphanedFiles
          file.remove (err) =>
            if err then @emit 'warn', "Error deleting file",
              error: wrapDbError err
              projectId: projectId
              fileId: file._id
      
  _cleanupLineEndings = (contents) ->
    return contents unless (/\r/.test contents)
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
    updateContents = (err, contents)=>
      @emit 'debug', "Returned file from dementor", {hasError:err?, projectId:projectId, fileId:fileId}
      return callback err if err
      checksum = crc32 contents if contents?
      if reset then @emit 'debug', "Resetting file contents", {projectId:projectId, fileId:fileId}
      @azkaban.bolideClient.setDocumentContents fileId, contents, reset, (err) =>
        callback err, checksum


    Project.findOne _id: projectId, (err, project)=>
      console.log "### FS project", project
      unless project and project.impressJS
        throw new Error 'DementorChannel is obsoleted; please update calling function.'
      else
        File.findOne _id: fileId, (err,file)->
          fs.readFile "#{Settings.userStaticFiles}/#{projectId}/#{file.path}", "utf-8", (err, contents)->
            updateContents(err, contents)

  #callback: (err, scratchFile) ->
  addScratchFile: (projectId, callback) ->
    SCRATCH_PATH = "%SCRATCH%"
    ORDERING_PATH = "!!SCRATCH"
    scratch = new File {path:SCRATCH_PATH, projectId:projectId,\
      isDir:false, scratch:true, orderingPath:ORDERING_PATH}
    scratch.save (err, doc) ->
      err = wrapDbError err if err
      callback err, doc

module.exports = FileSyncer
