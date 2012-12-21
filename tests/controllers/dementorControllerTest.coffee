assert = require 'assert'
request = require 'request'
url = require 'url'
uuid = require 'node-uuid'
app = require '../../app'
{ServiceKeeper} = require '../../ServiceKeeper'
{MongoConnector} = require '../../src/mongoConnector'
{MockDb} = require '../mock/MockMongo'
{Settings} = require 'madeye-common'
{messageMaker, messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'

sendInitRequest = (mockDb, projectName, objects, done) ->
  options =
    method: "POST"
    uri: "http://localhost:#{app.get('port')}/project/#{projectName}"
  sendRequest mockDb, options, objects, done

sendRefreshRequest = (mockDb, projectId, objects, done) ->
  options =
    method: "PUT"
    uri: "http://localhost:#{app.get('port')}/project/#{projectId}"
  sendRequest mockDb, options, objects, done

sendRequest = (mockDb, options, objects, done) ->
  if mockDb?
    mongoConnector = new MongoConnector(mockDb)
    ServiceKeeper.mongoConnector = mongoConnector
  else
    ServiceKeeper.reset()

  objects ?= {}
  request options, (err, _res, _body) ->
    #console.log "Found body ", _body
    objects.bodyStr = _body
    try
      objects.body = JSON.parse _body
    catch error
      "Let the test catch this."
    objects.response = _res
    done()

assertResponseOk = (objects, isError=false, errorType=null) ->
  it "returns a 200", ->
    assert.ok objects.response.statusCode == 200
  it "returns valid JSON", ->
    assert.doesNotThrow ->
      JSON.parse(objects.bodyStr)
  if isError
    it "returns an error", ->
      assert.ok objects?.body?.error, "Body #{objects.bodyStr} doesn't have error property."
    it "returns an error with the correct type", ->
      assert.equal objects.body.error.type, errorType
  else
    it "does not return an error", ->
      assert.equal objects.body.error, null, "Body #{objects.bodyStr} should not have an error."


describe "DementorController with real db", ->

  describe "init", ->
    projectName = 'cleesh'
    objects = {}
    before (done) ->
      sendInitRequest(null, projectName, objects, done)
    it "returns a 200", ->
      assert.ok objects.response.statusCode == 200
    it "returns valid JSON", ->
      assert.doesNotThrow ->
        JSON.parse(objects.bodyStr)
    it "returns the correct projectName", ->
      assert.equal objects.body.name, projectName
    it "returns an id", ->
      assert.ok objects.body.id, "Body #{objects.bodyStr} doesn't have id property."
    it "returns a url", ->
      assert.ok objects.body.url, "Body #{objects.bodyStr} doesn't have url property."
    it "returns a url with the correct hostname", ->
      #console.log "Found url:", objects.body.url
      u = url.parse(objects.body.url)
      assert.ok u.hostname
      assert.equal u.hostname, Settings.apogeeHost


describe "DementorController", ->

  describe "init", ->
    projectName = 'golmac'
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      sendInitRequest(mockDb, projectName, objects, done)
    assertResponseOk objects
    it "returns the correct projectName", ->
      assert.equal objects.body.name, projectName
    it "returns an id", ->
      assert.ok objects.body.id, "Body #{objects.bodyStr} doesn't have id property."
    it "returns a url", ->
      assert.ok objects.body.url, "Body #{objects.bodyStr} doesn't have url property."
    it "returns a url with the correct hostname", ->
      #console.log "Found url:", objects.body.url
      u = url.parse(objects.body.url)
      assert.ok u.hostname
      assert.equal u.hostname, Settings.apogeeHost

  describe "init with error in opening db", ->
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open connection to MongoDb."
      mockDb.openError = new Error(errMsg)
      sendInitRequest(mockDb, 'exex', objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  describe "init with error in opening collection", ->
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open collection."
      mockDb.collectionError = new Error errMsg
      sendInitRequest(mockDb, 'exex', objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  describe "init with error in insert", ->
    objects = {}
    errMsg = null
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot insert document."
      mockDb.crudError = new Error(errMsg)
      sendInitRequest(mockDb, 'exex', objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR


  describe "refresh", ->
    projectName = 'gloth'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      mockDb.load MongoConnector.prototype.PROJECT_COLLECTION,
        _id: projectId
        name: projectName
      sendRefreshRequest(mockDb, projectId, objects, done)
    assertResponseOk objects
    it "returns an id", ->
      assert.ok objects.body.id, "Body #{objects.bodyStr} doesn't have id property."
    it "returns the correct projectId", ->
      assert.equal objects.body.id, projectId
    it "returns a url", ->
      assert.ok objects.body.url, "Body #{objects.bodyStr} doesn't have url property."
    it "returns a url with the correct hostname", ->
      #console.log "Found url:", objects.body.url
      u = url.parse(objects.body.url)
      assert.ok u.hostname
      assert.equal u.hostname, Settings.apogeeHost

  describe "refresh with missing project", ->
    projectName = 'gloth'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      sendRefreshRequest(mockDb, projectId, objects, done)
    assertResponseOk objects, true, errorType.MISSING_OBJECT

  describe "refresh with db open error", ->
    projectName = 'umboz'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open connection to MongoDb."
      mockDb.openError = new Error(errMsg)
      sendRefreshRequest(mockDb, projectId, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  describe "refresh with db collection error", ->
    projectName = 'umboz'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open collection."
      mockDb.collectionError = new Error errMsg
      sendRefreshRequest(mockDb, projectId, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  describe "refresh with db crud error fweep", ->
    projectName = 'umboz'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      mockDb.load MongoConnector.prototype.PROJECT_COLLECTION,
        _id: projectId
        name: projectName
      errMsg = "Cannot remove document."
      mockDb.crudError = new Error(errMsg)
      sendRefreshRequest(mockDb, projectId, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

