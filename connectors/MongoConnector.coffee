mongo = require 'mongodb'

DB_NAME = 'apogee'
PROJECT_COLLECTION = 'projects'
FILES_COLLECTION = 'files'

class MongoHelper
  constructor: (@db, @callback) ->

  handleError: (err) ->
    @error = err
    console.error "Found error:", err
    @db.close()
    @callback(err, null)

  handleResult: (result) ->
    console.log "Found " + result?.length + " result."
    @result = result
    @db.close()
    @callback(null, result)

class MongoConnector
  constructor: (@db) ->

  #callback = (err, objects) ->
  insert: (objects, collectionName, callback) ->
    #console.log "Calling insert with callback", callback
    helper = new MongoHelper(@db, callback)
    @db.open (err, db) ->
      if err
        helper.handleError err
      else
        console.log "We are connected to #{DB_NAME}"
        db.collection collectionName, (err, collection) ->
          if err
            helper.handleError err
          else
            console.log "Opening collection #{collectionName}"
            collection.insert objects, {safe:true}, (err, result) ->
              if err
                helper.handleError err
              else
                console.log "typeof result:", typeof result
                console.log "Found insert result", result
                helper.handleResult result

  createProject: (callback) ->
    projects = [{created:new Date().getTime()}]
    @insert projects, PROJECT_COLLECTION, callback
    
  addFile: (file, projectId, callback) ->
    @addFiles([file], projectId)

  addFiles: (files, projectId, callback) ->
    for file in files
      file.projectId = projectId
    @insert files, FILES_COLLECTION, callback

MongoConnector.instance = (hostname, port) ->
  server = new mongo.Server(hostname, port, {auto_reconnect: true})
  db = new mongo.Db(DB_NAME, server, {safe:true})
  return new MongoConnector(db)


    

exports.MongoConnector = MongoConnector
