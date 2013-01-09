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

sendInitRequest = (mockDb, projectName, files, objects, done) ->
  options =
    method: "POST"
    uri: "http://localhost:#{app.get('port')}/project/#{projectName}"
    json: {files:files}
  sendRequest mockDb, options, objects, done

sendRefreshRequest = (mockDb, projectId, files, objects, done) ->
  options =
    method: "PUT"
    uri: "http://localhost:#{app.get('port')}/project/#{projectId}"
    json: {files:files}
  sendRequest mockDb, options, objects, done

sendRequest = (mockDb, options, objects, done) ->
  if mockDb?
    mongoConnector = new MongoConnector(mockDb)
    ServiceKeeper.mongoConnector = mongoConnector
  else
    ServiceKeeper.reset()

  objects ?= {}
  request options, (err, _res, _body) ->
    console.log "Found body ", _body
    console.log "Body type", typeof _body
    if typeof _body == 'string'
      objects.bodyStr = _body
      try
        objects.body = JSON.parse _body
      catch error
        "Let the test catch this."
    else
      objects.body = _body
    objects.response = _res
    done()

assertResponseOk = (objects, isError=false, errorType=null) ->
  it "returns a 200", ->
    assert.ok objects.response.statusCode == 200
  if isError
    it "returns an error", ->
      assert.ok objects?.body?.error, "Body #{objects.bodyStr} doesn't have error property."
    it "returns an error with the correct type", ->
      assert.equal objects.body.error.type, errorType
  else
    it "does not return an error", ->
      assert.equal objects.body.error, null, "Body #{objects.bodyStr} should not have an error."

describe "DementorController with real db", ->
  files = [
    {isDir: false, path:'file1'},
          {isDir: true, path:'dir1'},
          {isDir: false, path:'dir1/file2'}
  ]

  assertValidResponseBody = (objects, projectName) ->
    it "returns an id", ->
      assert.ok objects.body.id, "Body #{objects.bodyStr} doesn't have id property."
    it "returns a url", ->
      assert.ok objects.body.url, "Body #{objects.bodyStr} doesn't have url property."
    it "returns a url with the correct hostname", ->
      #console.log "Found url:", objects.body.url
      u = url.parse(objects.body.url)
      assert.ok u.hostname
      assert.equal u.hostname, Settings.apogeeHost
    it "returns a project with valid info", ->
      project = objects.body.project
      assert.ok project
      assert.ok project._id
      assert.equal project._id, objects.body.id
      assert.equal project.name, projectName
    it "returns files correctly", ->
      returnedFiles = objects.body.files
      assert.ok returnedFiles
      assert.equal returnedFiles.length, files.length
      assert.ok file._id for file in returnedFiles


  describe "init", ->
    projectName = 'cleesh'
    objects = {}
    before (done) ->
      sendInitRequest(null, projectName, files, objects, done)
    assertResponseOk objects
    assertValidResponseBody objects, projectName

  describe "refresh fweep", ->
    projectName = 'yimfil'
    projectId = null
    objects = {}
    before (done) ->
      mongo = ServiceKeeper.mongoInstance()
      mongo.createProject projectName, files, (err, results) ->
        assert.equal err, null
        projectId = results.project._id
        console.log "Created project with id #{projectId}"
        sendRefreshRequest(null, projectId, files, objects, done)

    assertResponseOk objects
    assertValidResponseBody objects, projectName
    it "should keep the right project id", ->
      assert.equal objects.body.id, projectId


describe "DementorController", ->
  files = [
    {isDir: false, path:'file1'},
          {isDir: true, path:'dir1'},
          {isDir: false, path:'dir1/file2'}
  ]

  describe "init", ->
    projectName = 'golmac'
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      sendInitRequest(mockDb, projectName, files, objects, done)
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
      sendInitRequest(mockDb, 'exex', files, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  describe "init with error in opening collection", ->
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open collection."
      mockDb.collectionError = new Error errMsg
      sendInitRequest(mockDb, 'exex', files, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  describe "init with error in insert", ->
    objects = {}
    errMsg = null
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot insert document."
      mockDb.crudError = new Error(errMsg)
      sendInitRequest(mockDb, 'exex', files, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  #TODO: Refactor out repeated code.
  describe "refresh", ->
    projectName = 'gloth'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      mockDb.load MongoConnector.prototype.PROJECT_COLLECTION,
        _id: projectId
        name: projectName
      sendRefreshRequest(mockDb, projectId, files, objects, done)
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

    it "updates existing files in db for project"

  describe "refresh with missing project", ->
    projectName = 'gloth'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      sendRefreshRequest(mockDb, projectId, files, objects, done)
    assertResponseOk objects, true, errorType.MISSING_OBJECT

  describe "refresh with db open error", ->
    projectName = 'umboz'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open connection to MongoDb."
      mockDb.openError = new Error(errMsg)
      sendRefreshRequest(mockDb, projectId, files, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  describe "refresh with db collection error", ->
    projectName = 'umboz'
    projectId = uuid.v4()
    objects = {}
    before (done) ->
      mockDb = new MockDb()
      errMsg = "Cannot open collection."
      mockDb.collectionError = new Error errMsg
      sendRefreshRequest(mockDb, projectId, files, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

  describe "refresh with db crud error", ->
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
      sendRefreshRequest(mockDb, projectId, files, objects, done)
    assertResponseOk objects, true, errorType.DATABASE_ERROR

