assert = require 'assert'
request = require 'request'
url = require 'url'
app = require '../../app'
{ServiceKeeper} = require '../../ServiceKeeper'
{MongoConnector} = require '../../connectors/MongoConnector'
{MockDb} = require '../mock/MockMongo'

sendInitRequest = (mockDb, objects, done) ->
  if mockDb
    mongoConnector = new MongoConnector(mockDb)
    ServiceKeeper.mongoConnector = mongoConnector
  objects ?= {}
  options =
    uri: "http://localhost:#{app.get('port')}/init"
  request options, (err, _res, _body) ->
    console.log "Found body ", _body
    objects.bodyStr = _body
    try
      objects.body = JSON.parse _body
    catch error
      "Let the test catch this."
    objects.response = _res
    done()

describe "controllers/dementor", ->
  describe "init", ->
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      sendInitRequest(mockDb, objects, done)
    it "returns a 200", ->
      assert.ok objects.response.statusCode == 200
    it "returns valid JSON", ->
      assert.doesNotThrow ->
        JSON.parse(objects.bodyStr)
    it "returns a url", ->
      assert.ok objects.body.url, "Body #{objects.bodyStr} doesn't have url property."
    it "returns a url with the correct hostname", ->
      console.log "Found url:", objects.body.url
      u = url.parse(objects.body.url)
      assert.ok u.hostname
      assert.equal u.hostname, app.get('apogee.hostname')

  describe "init with error in opening", ->
    objects = {}
    errMsg = null
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open connection to MongoDb."
      mockDb.openError = new Error(errMsg)
      sendInitRequest(mockDb, objects, done)
    it "returns a 200", ->
      assert.ok objects.response.statusCode == 200
    it "returns valid JSON", ->
      assert.doesNotThrow ->
        JSON.parse(objects.bodyStr)
    it "returns an error", ->
      assert.ok objects.body.error, "Body #{objects.bodyStr} doesn't have error property."
    it "returns an error with the correct message", ->
      console.log "Found error:", objects.body.error
      assert.equal errMsg, objects.body.error

  describe "init with error in opening", ->
    objects = {}
    errMsg = null
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open collection."
      mockDb.collectionError = new Error(errMsg)
      sendInitRequest(mockDb, objects, done)
    it "returns a 200", ->
      assert.ok objects.response.statusCode == 200
    it "returns valid JSON", ->
      assert.doesNotThrow ->
        JSON.parse(objects.bodyStr)
    it "returns an error", ->
      assert.ok objects.body.error, "Body #{objects.bodyStr} doesn't have error property."
    it "returns an error with the correct message", ->
      console.log "Found error:", objects.body.error
      assert.equal errMsg, objects.body.error

  describe "init with error in insert", ->
    objects = {}
    errMsg = null
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot insert document."
      mockDb.crudError = new Error(errMsg)
      sendInitRequest(mockDb, objects, done)
    it "returns a 200", ->
      assert.ok objects.response.statusCode == 200
    it "returns valid JSON", ->
      assert.doesNotThrow ->
        JSON.parse(objects.bodyStr)
    it "returns an error", ->
      assert.ok objects.body.error, "Body #{objects.bodyStr} doesn't have error property."
    it "returns an error with the correct message", ->
      console.log "Found error:", objects.body.error
      assert.equal errMsg, objects.body.error