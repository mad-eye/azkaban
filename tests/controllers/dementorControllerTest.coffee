assert = require 'assert'
request = require 'request'
url = require 'url'
uuid = require 'node-uuid'
{MockDb} = require '../mock/MockMongo'
{Settings} = require 'madeye-common'
#Freeze errors.coffee from pre-ddp version
{errors, errorType} = require '../../src/errors'
testUtils = require '../util/testUtils'
{Project} = require '../../src/models'
DementorController = require '../../src/dementorController'
server = require "../../server"


###
# Request helper methods
###

minDementorVersion = (new DementorController).minDementorVersion

sendInitRequest = (projectName, files, objects, done) ->
  options =
    method: "POST"
    uri: "http://localhost:#{Settings.azkabanPort}/project"
    json:
      files: files
      projectName: projectName
      version: minDementorVersion
  sendRequest options, objects, done

sendRefreshRequest = (projectId, projectName, files, objects, done) ->
  options =
    method: "PUT"
    uri: "http://localhost:#{Settings.azkabanPort}/project/#{projectId}"
    json:
      files: files
      projectName: projectName
      version: minDementorVersion
  sendRequest options, objects, done

sendRequest = (options, objects, done) ->
  objects ?= {}
  request options, (err, _res, _body) ->
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
  if isError
    it "returns a 500", ->
      assert.ok objects.response.statusCode == 500
    it "returns an error", ->
      assert.ok objects?.body?.error, "Body #{objects.bodyStr} doesn't have error property."
    it "returns an error with the correct type", ->
      assert.equal objects.body.error.type, errorType
  else
    it "returns a 200", ->
      assert.ok objects.response.statusCode == 200
    it "does not return an error", ->
      assert.equal objects.body.error, null, "Body #{objects.bodyStr} should not have an error."

describe "DementorController (functional)", ->
  # INTEGRATION TEST -- requires app and MongoDb to be running.
  server.listen()

  files = [
    {isDir: false, path:'file1'},
          {isDir: true, path:'dir1'},
          {isDir: false, path:'dir1/file2'}
  ]

  describe "init", ->
    projectName = 'cleesh'
    objects = {}
    before (done) ->
      sendInitRequest(projectName, files, objects, done)
    assertResponseOk objects, true, errorType.OUT_OF_DATE

  describe "refresh", ->
    projectName = 'yimfil'
    objects = {}
    before (done) ->
      projectId = uuid.v4()
      sendRefreshRequest(projectId, projectName, files, objects, done)

    assertResponseOk objects, true, errorType.OUT_OF_DATE

  describe "refresh with missing id", ->
    projectName = 'otsung'
    objects = {}
    before (done) ->
      projectId = uuid.v4()
      sendRefreshRequest(projectId, projectName, files, objects, done)

    assertResponseOk objects, true, errorType.OUT_OF_DATE

