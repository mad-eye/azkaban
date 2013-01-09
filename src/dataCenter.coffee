{MongoConnection} = require './mongoConnection'
uuid = require 'node-uuid'

class DataCenter
  constructor: ->

  getConnection: (errorHandler) ->
    MongoConnection.instance errorHandler

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

  #callback: (results) ->
  getFilesForProject: (db, projectId, callback) ->
      db.collection @FILES_COLLECTION, (err, collection) ->
        if err then helper.handleError err; return
        cursor = collection.find {projectId:projectId}
        cursor.toArray (err, results) ->
          if err then helper.handleError err; return
          helper.handleResult results




DataCenter.prototype['PROJECT_COLLECTION'] = DataCenter['PROJECT_COLLECTION'] = DataCenter.PROJECT_COLLECTION = 'projects'
DataCenter.prototype['FILES_COLLECTION'] = DataCenter['FILES_COLLECTION'] = DataCenter.FILES_COLLECTION = 'files'

exports.DataCenter = DataCenter
