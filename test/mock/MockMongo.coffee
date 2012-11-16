uuid = require 'node-uuid'

#@openError: Error to be thrown on open.
#@collectionError: Error to be thrown on collection
#@crudError: Error to be thrown on CRUD operation
class MockDb
  constructor: (@name, @server) ->
    @collections = {}

  open: (callback) ->
    if @openError
      callback(@openError)
    else
      callback(null, this)

  close: () ->
    #console.log "Closing db"

  collection: (name, options, callback) ->
    unless callback?
      callback = options
      options = {}
    if @collectionError
      callback(@collectionError)
      return
    if !@collections[name]
      if options.safe
        callback(new Error('Collection does not exist: ' +name))
        return
      else
        @collections[name] = new MockCollection(name, @crudError)
    callback(null, @collections[name])

  createCollection: (name, options, callback) ->
    unless callback?
      callback = options
      options = {}
    if @collectionError
      callback(@collectionError)
      return
    if @collections[name]
      if options.safe
        callback(new Error('Collection already exists: ' +name))
        return
    else
      @collections[name] = new MockCollection(name, @crudError)
    callback(null, @collections[name])


#@crudError: Error to be thrown on CRUD operation
class MockCollection
  constructor: (@name, @crudError) ->
    @documents = {}

  insert: (docs, options, callback) ->
    unless callback?
      callback = options
      options = {}
    if @crudError
      callback(@crudError)
      return
    for doc in docs
      doc._id = uuid.v4()
      @documents[doc._id] = doc
      
    callback(null, docs)


exports.MockDb = MockDb
