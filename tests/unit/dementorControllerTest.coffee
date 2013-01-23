assert = require 'assert'
sinon = require 'sinon'
uuid = require 'node-uuid'
url = require 'url'
_ = require 'underscore'
{errors, errorType} = require 'madeye-common'
{Settings} = require 'madeye-common'
DementorController = require '../../src/dementorController'
MockResponse = require '../mock/mockResponse'
testUtils = require '../util/testUtils'
{Project} = require '../../src/models'

assertFilesCorrect = testUtils.assertFilesCorrect

describe 'DementorController', ->
  dementorController = new DementorController

  newFiles = [
    { path: 'file1', isDir:false },
    { path: 'dir1', isDir:true},
    { path: 'dir1/file2', isDir:false }
  ]
  
  describe 'createProject', ->
    projectName = 'golmac'
    projectId = null
    result = body = null
    before (done) ->
      req =
        body: {files: newFiles, projectName:projectName}
      res = new MockResponse

      res.end = (_body) ->
        assert.ok _body
        body = _body
        result = JSON.parse _body
        done()

      dementorController.createProject req, res

    it "does not return an error", ->
      assert.equal result.error, null, "Body #{body} should not have an error."
    it "returns a project with valid info", ->
      project = result.project
      assert.ok project
      assert.ok project._id
      assert.equal project.name, projectName
    it "returns files correctly", ->
      returnedFiles = result.project.files
      assert.ok returnedFiles
      assertFilesCorrect returnedFiles, newFiles, projectId

    describe "with error", ->
      body = statusCode = null
      before (done) ->
        req =
          params: {projectName:projectName}
          body: {files: newFiles}
        res = new MockResponse

        dementorController.dataCenter = createProject: (projName, files, callback) ->
          callback errors.new errorType.DATABASE_ERROR

        res.end = (_body) ->
          statusCode = res.statusCode
          assert.ok _body
          result = JSON.parse _body
          done()
        dementorController.createProject req, res

      #Commenting out and making pending until we can mock mongoose to throw errors.
      it "returns an error"
      it "returns an error with the correct type"
      #it "returns an error", ->
        #assert.ok result.error, "Body #{body} doesn't have error property."
      #it "returns an error with the correct type", ->
        #assert.equal result.error.type, errorType.DATABASE_ERROR

  describe "refreshProject fweep", ->
    projectName = 'gloth'
    projectId = null
    result = body = null
    before (done) ->
      project = new Project
        name: projectName
        files: newFiles
      project.save (err) ->
        assert.equal err, null
        projectId = project._id

        req =
          params: {projectId:projectId}
          body: {projectName:projectName, files:newFiles}
        res = new MockResponse
        res.end = (_body) ->
          assert.ok _body
          body = _body
          result = JSON.parse _body
          console.log "Found response body", result
          done()

        dementorController.refreshProject req, res

    it "does not return an error", ->
      assert.equal result.error, null, "Body #{body} should not have an error."
    it "returns a project with valid info", ->
      project = result.project
      assert.ok project
      assert.ok project._id
      assert.equal project._id, projectId
      assert.equal project.name, projectName
    it "returns files correctly", ->
      returnedFiles = result.project.files
      console.log "Returned files:", returnedFiles
      assert.ok returnedFiles
      assertFilesCorrect returnedFiles, newFiles, projectId

    describe "with error", ->
      body = statusCode = null
      before (done) ->
        req =
          params: {projectId:projectId}
          body: {projectName:projectName, files:newFiles}
        res = new MockResponse

        dementorController.dataCenter = refreshProject: (proj, files, callback) ->
          callback errors.new errorType.DATABASE_ERROR

        res.end = (_body) ->
          statusCode = res.statusCode
          assert.ok _body
          result = JSON.parse _body
          done()
        dementorController.refreshProject req, res

      #Making tests pending until we can mock Mongoose and test errors.
      it "returns an error"
      it "returns an error with the correct type"
      #it "returns an error", ->
        #assert.ok result.error, "Body #{body} doesn't have error property."
      #it "returns an error with the correct type", ->
        #assert.equal result.error.type, errorType.DATABASE_ERROR

