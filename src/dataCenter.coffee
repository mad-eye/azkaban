uuid = require 'node-uuid'
{MongoConnection} = require './mongoConnection'
{errors, errorType} = require 'madeye-common'

class DataCenter
  constructor: ->

  getConnection: (errorHandler) ->
    new MongoConnection errorHandler

  #callback: (err, {project:, files:}) ->
  createProject: (projectName, files, callback) ->
    projects = [{_id: uuid.v4(), name: projectName, opened:true, created:new Date().getTime()}]
    db = @getConnection callback
    db.connect =>
      db.insert projects, @PROJECT_COLLECTION, (projs) =>
        project = projs[0]
        console.log "Inserted project", project
        @updateProjectFiles db, project._id, files, (files) =>
          callback null,
            project: project
            files: files
          db.close()

  #callback: (err) ->
  closeProject: (projectId, callback) ->
    db = @getConnection callback
    db.connect =>
      db.updateObject projectId, @PROJECT_COLLECTION, {opened:false}, (count) ->
        callback()
        db.close()

  #callback: (err, {project:, files:}) ->
  refreshProject: (projectId, files, callback) ->
    db = @getConnection callback
    db.connect =>
      db.findAndModifyObject projectId, @PROJECT_COLLECTION, {opened:true}, (project) =>
        unless project?
          callback errors.new(errorType.MISSING_OBJECT, objectId: projectId)
          return
        @updateProjectFiles db, projectId, files, (results) =>
          callback null,
            project: project
            files: results
          db.close()

  #callback: (files) ->
  #options: noclobber: bool -- if true, don't delete entries in db not in files
  updateProjectFiles: (db, projectId, files=[], options = {}, callback) ->
    if typeof options == 'function'
      callback = options
      options = {}

    db.findAll @FILES_COLLECTION, {projectId: projectId}, (existingFiles) =>
      #XXX: Is there a cleaner way to do this in JS?
      #We want to find which files we already have, and which files don't exist anymore.
      existingFilesMap = {}
      existingFilesMap[file.path] = file for file in existingFiles
      filesToAdd = []
      filesToReturn = []
      for file in files
        if existingFile = existingFilesMap[file.path]
          delete existingFilesMap[file.path]
          filesToReturn.push existingFile
        else
          file.projectId = projectId
          file._id = uuid.v4()
          filesToAdd.push file

      if filesToAdd.length == 0
        callback filesToReturn
      else
        db.insert filesToAdd, @FILES_COLLECTION, (result) ->
          filesToReturn = filesToReturn.concat result
          callback filesToReturn

      unless options.noclobber
        removeIds = (file._id for fake, file of existingFilesMap)
        if removeIds.length > 0
          db.remove removeIds, @FILES_COLLECTION

  addFiles: (files, projectId, callback) ->
    db = @getConnection callback
    db.connect =>
      @updateProjectFiles db, projectId, files, noclobber:true, (files) ->
        callback null, files
        db.close()



DataCenter.prototype['PROJECT_COLLECTION'] = DataCenter['PROJECT_COLLECTION'] = DataCenter.PROJECT_COLLECTION = 'projects'
DataCenter.prototype['FILES_COLLECTION'] = DataCenter['FILES_COLLECTION'] = DataCenter.FILES_COLLECTION = 'files'

exports.DataCenter = DataCenter
