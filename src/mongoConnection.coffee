mongo = require 'mongodb'
{Settings, errors, errorType} = require 'madeye-common'

DB_NAME = 'meteor'

wrapError = (err) ->
  errors.new errorType.DATABASE_ERROR, err

class MongoConnection
  constructor: (@errorHandler) ->
    server = new mongo.Server(Settings.mongoHost, Settings.mongoPort, {auto_reconnect: true})
    @Db = new mongo.Db(DB_NAME, server, {safe:true})
    
  close: =>
    process.nextTick =>
      @db?.close()

  handleError: (err) =>
    console.error "Handling error", err
    @errorHandler wrapError err

  connect: (callback) =>
    @handleError new Error "Connection aready opening" if @open
    @open = true
    @Db.open (err, @db) =>
      if err then @handleError err; return
      callback()

  #callback: (collection) ->
  getCollection: (collectionName, callback) =>
    return unless @check collectionName, callback
    @db.collection collectionName, (err, collection) =>
      if err then @handleError err; return
      callback collection
    
  #callback = (objects) ->
  insert: (objects, collectionName, callback) =>
    return unless @check collectionName, callback
    @getCollection collectionName, (collection) =>
      collection.insert objects, {safe:true}, (err, result) =>
        if err then @handleError err; return
        callback result

  #callback: () ->, null ok
  remove: (selector, collectionName, callback) =>
    return unless @check collectionName, callback
    @getCollection collectionName, (collection) ->
      collection.remove selector, () ->
        callback?()

  #callback: (count) ->
  updateObject: (objectId, collectionName, modifier, overwrite=false, callback) ->
    if typeof overwrite == 'function'
      callback = overwrite
      overwrite = false
    return unless @check collectionName, callback
    @getCollection collectionName, (collection) ->
      modifier = {$set: modifier} unless overwrite
      collection.update {_id:objectId}, modifier, {safe:true}, (err, result) ->
        if err then @handleError err; return
        callback result

  #callback: (object) ->
  findAndModifyObject: (objectId, collectionName, modifier, overwrite, callback) ->
    if typeof overwrite == 'function'
      callback = overwrite
      overwrite = false

    @getCollection collectionName, (collection) =>
      modifier = {$set: modifier} unless overwrite
      collection.findAndModify {_id:objectId}, {}, modifier, {safe:true, new:true}, (err, result) =>
        if err then @handleError err; return
        callback result

  #callback: (documents) ->
  findAll: (collectionName, selector, callback) ->
    return unless @check collectionName, callback
    @getCollection collectionName, (collection) ->
      collection.find(selector).toArray (err, docs) ->
        if err then @handleError err; return
        callback docs
        


  check: (collectionName, callback) ->
    unless typeof collectionName == 'string'
      @handleError new Error "Collection name #{collectionName} is not a string."
      return false
    if callback? and typeof callback != 'function'
      @handleError new Error "Callback is not a function:", callback
      return false
    return true

MongoConnection.instance = (errorHandler) ->
    return new MongoConnection errorHandler

  
exports.MongoConnection = MongoConnection
