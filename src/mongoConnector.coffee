mongo = require 'mongodb'
uuid = require 'node-uuid'
flow = require 'flow'
{errors, errorType} = require 'madeye-common'

DB_NAME = 'meteor'

wrapError = (err) ->
  errors.new errorType.DATABASE_ERROR, err

class MongoHelper
  constructor: (@Db, @callback) ->

  handleError: (err) ->
    @error = wrapError err
    console.error "Found error:", err
    @Db.close()
    @callback(@error, null)

  handleResult: (result) ->
    @result = result
    @Db.close()
    @callback(null, result)

class MongoConnector
  constructor: (@Db) ->

  #callback = (err, objects) ->
  insert: (objects, collectionName, callback) ->
    @Db.open (err, db) ->
      helper = new MongoHelper(db, callback)
      if err then helper.handleError err; return
      db.collection collectionName, (err, collection) ->
        if err then helper.handleError err; return
        collection.insert objects, {safe:true}, (err, result) ->
          if err then helper.handleError err; return
          helper.handleResult result

  #callback: (err, {project:, files:}) ->
  createProject: (projectName, files, callback) ->
    projects = [{_id: uuid.v4(), name: projectName, opened:true, created:new Date().getTime()}]
    @insert projects, @PROJECT_COLLECTION, (err, projs) =>
      if err then callback wrapError err; return
      project = projs[0]
      console.log "Inserted project", project
      @addFiles files, project._id, (err, files) =>
        if err then callback wrapError err; return
        callback null,
          project: project
          files: files

  #callback: (err, {project:, files:}) ->
  refreshProject: (projectId, files, callback) ->
    @findUpdateObject projectId, @PROJECT_COLLECTION, {opened:true}, (err, project) =>
      unless err? or project?
        err = errors.new(errorType.MISSING_OBJECT, objectId: projectId)
      if err then callback wrapError err; return
      @updateProjectFiles projectId, files, (err, results) =>
        if err then callback wrapError err; return
        callback null,
          project: project
          files: results

  #FIXME: This structure is painful.
  #callback: (err, {project:, files:}) ->
  #options: noclobber: bool -- if true, don't delete entries in db not in files
  updateProjectFiles: (projectId, files=[], options = {}, callback) ->
    if typeof options == 'function'
      callback = options
      options = {}
    @getFilesForProject projectId, (err, existingFiles) =>
      if err then callback wrapError err; return
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

      @Db.open (err, db) =>
        helper = new MongoHelper(db, callback)
        if err then helper.handleError err; return
        db.collection @FILES_COLLECTION, (err, collection) ->
          if err then helper.handleError err; return
          if filesToAdd.length > 0
            collection.insert filesToAdd, {safe:true}, (err, result) ->
              #Find some way to handle these orphaned errors
              if err then helper.handleError err; return
              filesToReturn = filesToReturn.concat result
              callback null, filesToReturn
          else
            callback null, filesToReturn
          unless options.noclobber
            removeIds = (file._id for fake, file of existingFilesMap)
            if removeIds.length > 0
              collection.remove removeIds, safe:false
          #When do we close the db?
          #db.close()

  addFile: (file, projectId, callback) ->
    @addFiles([file], projectId, callback)

  addFiles: (files, projectId, callback) ->
    @updateProjectFiles projectId, files, noclobber:true, callback


  getFile: (fileId, callback) ->
    @getObject fileId, @FILES_COLLECTION, callback

  getProject: (projectId, callback) ->
    @getObject projectId, @PROJECT_COLLECTION, callback

  #callback: (err, results) ->
  getFilesForProject: (projectId, callback) ->
    @Db.open (err, db) =>
      helper = new MongoHelper(db, callback)
      if err then helper.handleError err; return
      db.collection @FILES_COLLECTION, (err, collection) ->
        if err then helper.handleError err; return
        cursor = collection.find {projectId:projectId}
        cursor.toArray (err, results) ->
          if err then helper.handleError err; return
          helper.handleResult results

  #callback: (err, results) ->
  getObject: (objectId, collectionName, callback) ->
    console.log "Getting object #{objectId} from #{collectionName}"
    @Db.open (err, db) ->
      helper = new MongoHelper(db, callback)
      if err then helper.handleError err; return
      db.collection collectionName, (err, collection) ->
        if err then helper.handleError err; return
        cursor = collection.find {_id:objectId}
        cursor.nextObject (err, result) ->
          if err then helper.handleError err; return
          helper.handleResult result

  findUpdateObject: (objectId, collectionName, modifier, overwrite, callback) ->
    if typeof overwrite == 'function'
      callback = overwrite
      overwrite = false

    @Db.open (err, db) ->
      helper = new MongoHelper(db, callback)
      if err then helper.handleError err; return
      db.collection collectionName, (err, collection) ->
        if err then helper.handleError err; return
        modifier = {$set: modifier} unless overwrite
        collection.findAndModify {_id:objectId}, {}, modifier, {safe:true, new:true}, (err, result) ->
          if err then helper.handleError err; return
          helper.handleResult result

  updateObject: (objectId, collectionName, modifier, overwrite, callback) ->
    if typeof overwrite == 'function'
      callback = overwrite
      overwrite = false

    @Db.open (err, db) ->
      helper = new MongoHelper(db, callback)
      if err then helper.handleError err; return
      db.collection collectionName, (err, collection) ->
        if err then helper.handleError err; return
        modifier = {$set: modifier} unless overwrite
        collection.update {_id:objectId}, modifier, {safe:true}, (err, result) ->
          if err then helper.handleError err; return
          helper.handleResult result

MongoConnector.instance = (hostname, port) ->
  server = new mongo.Server(hostname, port, {auto_reconnect: true})
  Db = new mongo.Db(DB_NAME, server, {safe:true})
  return new MongoConnector(Db)


MongoConnector.prototype['PROJECT_COLLECTION'] = MongoConnector['PROJECT_COLLECTION'] = MongoConnector.PROJECT_COLLECTION = 'projects'
MongoConnector.prototype['FILES_COLLECTION'] = MongoConnector['FILES_COLLECTION'] = MongoConnector.FILES_COLLECTION = 'files'

exports.MongoConnector = MongoConnector
