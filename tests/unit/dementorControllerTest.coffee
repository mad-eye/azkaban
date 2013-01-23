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
        params: {projectName:projectName}
        body: {files: newFiles}
      res = new MockResponse

      dementorController.dataCenter = createProject: (proj, files, callback) ->
        projectId = proj.projectId ? uuid.v4()
        project = {_id: projectId, name: proj.projectName, opened:true, created:new Date().getTime()}
        returnFiles = []
        for file in files
          f = _.clone file
          f._id = uuid.v4()
          f.projectId = projectId
          returnFiles.push f
        callback null,
          project: project
          files: returnFiles

      res.end = (_body) ->
        assert.ok _body
        body = _body
        result = JSON.parse _body
        done()

      dementorController.createProject req, res

    it "does not return an error", ->
      assert.equal result.error, null, "Body #{body} should not have an error."
    it "returns an id", ->
      assert.ok result.id, "Body #{body} doesn't have id property."
    it "returns a url", ->
      assert.ok result.url, "Body #{body} doesn't have url property."
    it "returns a url with the correct hostname", ->
      #console.log "Found url:", result.url
      u = url.parse(result.url)
      assert.ok u.hostname
      assert.equal u.hostname, Settings.apogeeHost
    it "returns a project with valid info", ->
      project = result.project
      assert.ok project
      assert.ok project._id
      assert.equal project._id, result.id
      assert.equal project.name, projectName
    it "returns files correctly", ->
      returnedFiles = result.files
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

      it "returns an error", ->
        assert.ok result.error, "Body #{body} doesn't have error property."
      it "returns an error with the correct type", ->
        assert.equal result.error.type, errorType.DATABASE_ERROR

  describe "refreshProject", ->
    projectName = 'gloth'
    projectId = null
    result = body = null
    before (done) ->
      projectId = uuid.v4()
      req =
        params: {projectId:projectId}
        body: {projectName:projectName, files:newFiles}
      res = new MockResponse

      dementorController.dataCenter = refreshProject: (proj, files, callback) ->
        project = {_id: proj.projectId, name: proj.projectName, opened:true, created:new Date().getTime()}
        returnFiles = []
        for file in files
          f = _.clone file
          f._id = uuid.v4()
          f.projectId = proj.projectId
          returnFiles.push f
        callback null,
          project: project
          files: returnFiles

      res.end = (_body) ->
        assert.ok _body
        body = _body
        result = JSON.parse _body
        done()

      dementorController.refreshProject req, res

    it "does not return an error", ->
      assert.equal result.error, null, "Body #{body} should not have an error."
    it "returns an id", ->
      assert.ok result.id, "Body #{body} doesn't have id property."
    it "returns a url", ->
      assert.ok result.url, "Body #{body} doesn't have url property."
    it "returns a url with the correct hostname", ->
      #console.log "Found url:", result.url
      u = url.parse(result.url)
      assert.ok u.hostname
      assert.equal u.hostname, Settings.apogeeHost
    it "returns a project with valid info", ->
      project = result.project
      assert.ok project
      assert.ok project._id
      assert.equal project._id, result.id
      assert.equal project.name, projectName
    it "returns files correctly", ->
      returnedFiles = result.files
      assert.ok returnedFiles
      assertFilesCorrect returnedFiles, newFiles, projectId
    it "returns the correct id", ->
      assert.equal result.id, projectId

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

      it "returns an error", ->
        assert.ok result.error, "Body #{body} doesn't have error property."
      it "returns an error with the correct type", ->
        assert.equal result.error.type, errorType.DATABASE_ERROR

