uuid = require 'node-uuid'

#@openError: Error to be thrown on open.
#@collectionError: Error to be thrown on collection
#@crudError: Error to be thrown on CRUD operation
class MockDb
  #Marker for mock object
  @isMock: true,

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

  #For test classes
  getCollection: (name, crudError) ->
    if @collections[name]
      return @collections[name]
    else
      @collections[name] = new MockCollection(name, crudError)

  #For test classes to set up data
  load: (collectionName, document) ->
    @getCollection('collectionName').load(document)

#@crudError: Error to be thrown on CRUD operation
class MockCollection
  #Marker for mock object
  @isMock: true,

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

  find: (query, fields, options) ->
    return new MockCursor(query, this)
    

  #For test classes to use
  load: (doc) ->
    @documents[doc._id] = doc

CursorINIT = 0
CursorOPEN = 1
CursorCLOSED = 2
    
#Callbacks are all of the form (err, doc) ->
#Currently, only selectors of the form
#{fieldName:fieldValue} are supported.
class MockCursor
  #Marker for mock object
  @isMock: true,

  constructor: (@query, @collection) ->
    @_findItems(@query, @collection)
    @index = 0
    @state = CursorINIT

  @_findItems: (query, collection) ->
    @items = _.filter(collection, (item) ->
      ok = true
      for fieldName, fieldValue of query
        ok = false if query.fieldName != fieldValue
        break unless ok
      return ok
    )

  sort: (fields) =>
    throw Error 'Not yet implemented in MockCursor.'
    return this

  limit: (n) =>
    throw Error 'Not yet implemented in MockCursor.'
    return this

  skip: (m) =>
    throw Error 'Not yet implemented in MockCursor.'
    return this

  nextObject: (callback) =>
    return callback new Error('Cursor is closed') if @state = CursorCLOSED
    if @state = CursorINIT
      @state = CursorOPEN
    if @index >= @items.length
      callback null, null
    else
      callback null, @items[@index++]

  each: (callback) =>
    unless callback
      throw new Error('callback is mandatory')
    if @state != CursorCLOSED
      # Fetch the next object until there is no more objects
      @nextObject (err, item) ->
        return callback(err, null) if err?
        if item?
          callback(null, item)
          self.each(callback)
        else
          # Close the cursor if done
          self.state = CursorCLOSED
          callback(err, null)
    else
      callback new Error("Cursor is closed"), null

  toArray: (callback) =>
    unless callback
      throw new Error('callback is mandatory')
    callback null, @items[@index..]

  #reset the cursor to its initial state.
  rewind: =>
    @index = 0
    return this

  count: =>
    return @items.length


exports.MockDb = MockDb
