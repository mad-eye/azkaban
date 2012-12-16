mongo = require 'mongodb'
uuid = require 'node-uuid'
{errors, errorType} = require 'madeye-common'

DB_NAME = 'meteor'
PROJECT_COLLECTION = 'projects'
FILES_COLLECTION = 'files'

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
      if err
        helper.handleError err
      else
        db.collection collectionName, (err, collection) ->
          if err
            helper.handleError err
          else
            collection.insert objects, {safe:true}, (err, result) ->
              if err
                helper.handleError err
              else
                helper.handleResult result

  createProject: (projectName, callback) ->
    projects = [{_id: uuid.v4(), name: projectName, created:new Date().getTime()}]
    @insert projects, PROJECT_COLLECTION, callback

  addFile: (file, projectId, callback) ->
    @addFiles([file], projectId)

  addFiles: (files, projectId, callback) ->
    for file in files
      file.projectId = projectId
      file._id = uuid.v4()
    @insert files, FILES_COLLECTION, callback


  getFile: (fileId, callback) ->
    console.log "Calling getFile with id #{fileId}"
    @getObject fileId, FILES_COLLECTION, callback

  getObject: (objectId, collectionName, callback) ->
    helper = new MongoHelper(@db, callback)

    console.log "Opening db."
    @db.open (err, db) ->
      console.log "Opened db."
      if err
        helper.handleError err
      else
        db.collection collectionName, (err, collection) ->
          if err
            helper.handleError err
          else
            cursor = collection.find {_id:objectId}
            cursor.nextObject (err, result) ->
              if err
                helper.handleError err
              else
                console.log "Found result from getObject #{objectId}:", result
                helper.handleResult result


MongoConnector.instance = (hostname, port) ->
  server = new mongo.Server(hostname, port, {auto_reconnect: true})
  db = new mongo.Db(DB_NAME, server, {safe:true})
  return new MongoConnector(db)




exports.MongoConnector = MongoConnector
