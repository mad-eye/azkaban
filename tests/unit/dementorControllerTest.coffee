{assert} = require 'chai'
sinon = require 'sinon'
uuid = require 'node-uuid'
url = require 'url'
_ = require 'underscore'
{errors, errorType} = require '../../src/errors'
DementorController = require '../../src/dementorController'
{MockResponse} = require 'madeye-common'
testUtils = require '../util/testUtils'
{Project, File} = require '../../src/models'
{Azkaban} = require '../../src/azkaban'
FileSyncer = require '../../src/fileSyncer'

assertFilesCorrect = testUtils.assertFilesCorrect

minDementorVersion = (new DementorController).minDementorVersion

describe 'DementorController', ->
  Azkaban.initialize()
  azkaban = Azkaban.instance()
  azkaban.setService 'fileSyncer', new FileSyncer()
  dementorController = new DementorController
  azkaban.setService 'dementorController', dementorController

  newFiles = [
    { path: 'file1', isDir:false },
    { path: 'dir1', isDir:true},
    { path: 'dir1/file2', isDir:false }
  ]

  describe 'createProject', ->
    res = req = null
    projectName = 'golmac'
    projectId = null
    now = Date.now()
    before ->
      req =
        body:
          files: newFiles
          projectName: projectName
          version: minDementorVersion
      res = new MockResponse

    #All calls should return out of date error
    it "returns out of date error", (done) ->
      res.onEnd = (_body) ->
        assert.equal res.statusCode, 500
        assert.ok _body
        result = JSON.parse _body
        assert.ok result.error, "Body #{_body} doesn't have error property."
        assert.equal result.error.type, errorType.OUT_OF_DATE
        done()
      dementorController.createProject req, res

  describe "refreshProject", ->
    res = body = statusCode = null
    projectName = 'lesoch'
    projectId = null
    beforeEach ->
      res = new MockResponse
      projectId = uuid.v4()

    #All invocations should return out of date error.
    it "returns out of date error", (done) ->
      req =
        params: {projectId:projectId}
        body:
          files: newFiles
          projectName: projectName
          version: minDementorVersion

      res.onEnd = (_body) ->
        assert.equal res.statusCode, 500
        assert.ok _body
        result = JSON.parse _body
        assert.ok result.error, "Body #{body} doesn't have error property."
        assert.equal result.error.type, errorType.OUT_OF_DATE
        done()
      dementorController.createProject req, res

