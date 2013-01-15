assert = require 'assert'
request = require 'request'
url = require 'url'
uuid = require 'node-uuid'
{DataCenter} = require '../../src/dataCenter'
{ServiceKeeper} = require '../../ServiceKeeper'
{MockDb} = require '../mock/MockMongo'
{Settings} = require 'madeye-common'
{messageMaker, messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
testUtils = require '../util/testUtils'

# INTEGRATION TEST -- requires app and MongoDb to be running.
require '../../app'

###
# Request helper methods
###

sendInitRequest = (projectName, files, objects, done) ->
  options =
    method: "POST"
    uri: "http://localhost:#{Settings.httpPort}/project/#{projectName}"
    json: {files:files}
  sendRequest options, objects, done

sendRefreshRequest = (projectId, files, objects, done) ->
  options =
    method: "PUT"
    uri: "http://localhost:#{Settings.httpPort}/project/#{projectId}"
    json: {files:files}
  sendRequest options, objects, done

sendRequest = (options, objects, done) ->
  objects ?= {}
  request options, (err, _res, _body) ->
    #console.log "Found body ", _body
    #console.log "Body type", typeof _body
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

###
# Real DB tests
###

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
      sendInitRequest(projectName, files, objects, done)
    assertResponseOk objects
    assertValidResponseBody objects, projectName

  describe "refresh", ->
    projectName = 'yimfil'
    projectId = null
    objects = {}
    before (done) ->
      dataCenter = new DataCenter
      dataCenter.createProject projectName, files, (err, results) ->
        assert.equal err, null
        projectId = results.project._id
        sendRefreshRequest(projectId, files, objects, done)

    assertResponseOk objects
    assertValidResponseBody objects, projectName
    it "should keep the right project id", ->
      assert.equal objects.body.id, projectId

    it "updates existing files in db for project"
