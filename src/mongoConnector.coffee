mongo = require 'mongodb'
uuid = require 'node-uuid'
{errors, errorType} = require 'madeye-common'

DB_NAME = 'meteor'

class MongoHelper
  constructor: (@db, @callback) ->

  handleError: (err) ->
    @error = errors.new errorType.DATABASE_ERROR, err
    console.error "Found error:", err
    @db.close()
    @callback(@error, null)

  handleResult: (result) ->
    @result = result
    @db.close()
    @callback(null, result)

class MongoConnector
  constructor: (@db) ->

  #callback = (err, objects) ->
  insert: (objects, collectionName, callback) ->
    helper = new MongoHelper(@db, callback)

    @db.open (err, db) ->
      if err then helper.handleError err; return
      db.collection collectionName, (err, collection) ->
        if err then helper.handleError err; return
        collection.insert objects, {safe:true}, (err, result) ->
          if err then helper.handleError err; return
          helper.handleResult result

  #callback: (err, projects) ->
  createProject: (projectName, callback) ->
    projects = [{_id: uuid.v4(), name: projectName, created:new Date().getTime()}]
    @insert projects, @PROJECT_COLLECTION, callback

  #callback: (err, projects) ->
  refreshProject: (projectId, callback) ->
    @getProject projectId, (err, project) =>
      unless err? or project?
        err = errors.new(errorType.MISSING_OBJECT, objectId: projectId)
      if err then callback err; return
      @deleteProjectFiles projectId, (err, results) =>
        if err then callback err; return
        callback null, project

  #callback: (err, results) ->
  deleteProjectFiles: (selector, callback) ->
    helper = new MongoHelper(@db, callback)

    @db.open (err, db) ->
      if err then helper.handleError err; return
      db.collection @FILES_COLLECTION, (err, collection) ->
        if err then helper.handleError err; return
        collection.remove selector, {safe:true}, (err, result) ->
          if err then helper.handleError err; return
          helper.handleResult result

  addFile: (file, projectId, callback) ->
    @addFiles([file], projectId)

  addFiles: (files, projectId, callback) ->
    for file in files
      file.projectId = projectId
      file._id = uuid.v4()
    @insert files, @FILES_COLLECTION, callback


  getFile: (fileId, callback) ->
    @getObject fileId, @FILES_COLLECTION, callback

  getProject: (projectId, callback) ->
    @getObject projectId, @PROJECT_COLLECTION, callback

  #callback: (err, results) ->
  getObject: (objectId, collectionName, callback) ->
    console.log "Getting object #{objectId} from #{collectionName}"
    helper = new MongoHelper(@db, callback)

    @db.open (err, db) ->
      if err then helper.handleError err; return
      db.collection collectionName, (err, collection) ->
        if err then helper.handleError err; return
        cursor = collection.find {_id:objectId}
        cursor.nextObject (err, result) ->
          if err then helper.handleError err; return
          helper.handleResult result


MongoConnector.instance = (hostname, port) ->
  server = new mongo.Server(hostname, port, {auto_reconnect: true})
  db = new mongo.Db(DB_NAME, server, {safe:true})
  return new MongoConnector(db)


MongoConnector.prototype['PROJECT_COLLECTION'] = MongoConnector['PROJECT_COLLECTION'] = MongoConnector.PROJECT_COLLECTION = 'projects'
MongoConnector.prototype['FILES_COLLECTION'] = MongoConnector['FILES_COLLECTION'] = MongoConnector.FILES_COLLECTION = 'files'

exports.MongoConnector = MongoConnector
