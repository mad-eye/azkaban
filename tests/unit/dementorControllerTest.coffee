{assert} = require 'chai'
sinon = require 'sinon'
uuid = require 'node-uuid'
url = require 'url'
_ = require 'underscore'
{errors, errorType} = require 'madeye-common'
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
  azkaban.setService 'ddpClient', invokeMethod: ->

  newFiles = [
    { path: 'file1', isDir:false },
    { path: 'dir1', isDir:true},
    { path: 'dir1/file2', isDir:false }
  ]

  describe 'createProject', ->
    describe 'without error', ->
      result = body = null
      projectName = 'golmac'
      projectId = null
      now = Date.now()
      before (done) ->
        req =
          body:
            files: newFiles
            projectName: projectName
            version: minDementorVersion

        res = new MockResponse
        res.onEnd = (_body) ->
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
        assert.isTrue project.lastOpened > now, "Project has lastOpened #{project.lastOpened} <= #{now}"
      it "returns files correctly", ->
        returnedFiles = result.files
        assert.ok returnedFiles
        assertFilesCorrect returnedFiles, newFiles, projectId
      #This completes in the background, not in time for this test
      #it "creates a scratch file", (done) ->
        #File.findOne {projectId: projectId, scratch:true}, (err, dbFile) ->
          #assert.isNotNull dbFile
          #assert.equal dbFile._id, scratchFile.id
          #done()


    describe "with error", ->
      res = body = statusCode = null
      projectName = 'onbit'
      beforeEach ->
        res = new MockResponse

      it 'should return correct error on missing version', (done) ->
        req =
          params: {projectName:projectName}
          body:
            files: newFiles
            projectName: projectName

        res.onEnd = (_body) ->
          assert.equal res.statusCode, 500
          assert.ok _body
          result = JSON.parse _body
          assert.ok result.error, "Body #{body} doesn't have error property."
          assert.equal result.error.type, errorType.OUT_OF_DATE
          done()
        dementorController.createProject req, res

      it 'should return correct error on too old version', (done) ->
        req =
          params: {projectName:projectName}
          body:
            files: newFiles
            projectName: projectName
            version: '0.0.10'

        res.onEnd = (_body) ->
          assert.equal res.statusCode, 500
          assert.ok _body
          result = JSON.parse _body
          assert.ok result.error, "Body #{_body} doesn't have error property."
          assert.equal result.error.type, errorType.OUT_OF_DATE
          done()
        dementorController.createProject req, res

      it "should return warning on too old nodejs version", (done) ->
        req =
          params: {projectName: projectName}
          body:
            files: newFiles
            projectName: projectName
            version: minDementorVersion
            nodeVersion: '0.4.0'

        res.onEnd = (_body) ->
          assert.equal res.statusCode, 200
          assert.ok _body
          result = JSON.parse _body
          assert.isFalse result.error?, "Should not return an error."
          assert.ok result.warning, "Body #{_body} doesn't have warning property."
          done()

        dementorController.createProject req, res

      #Commenting out and making pending until we can mock mongoose to throw errors.
      it "returns an error"
      it "returns an error with the correct type"
      #it "returns an error", ->
        #assert.ok result.error, "Body #{body} doesn't have error property."
      #it "returns an error with the correct type", ->
        #assert.equal result.error.type, errorType.DATABASE_ERROR

  describe "refreshProject", ->
    describe 'without error', ->
      result = body = null
      projectName = 'gloth'
      projectId = null
      now = Date.now()

      before (done) ->
        project = new Project
          name: projectName
          files: newFiles
        project.save (err) ->
          assert.equal err, null
          projectId = project._id

          req =
            params: {projectId:projectId}
            body:
              files: newFiles
              projectName: projectName
              version: minDementorVersion
          res = new MockResponse
          res.onEnd = (_body) ->
            assert.ok _body
            body = _body
            result = JSON.parse _body
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
        assert.isTrue project.lastOpened > now, "Project has lastOpened #{project.lastOpened} <= #{now}"
      it "returns files correctly", ->
        returnedFiles = result.files
        assert.ok returnedFiles
        assertFilesCorrect returnedFiles, newFiles, projectId

    describe "with error", ->
      res = body = statusCode = null
      projectName = 'lesoch'
      projectId = null
      beforeEach ->
        res = new MockResponse
        projectId = uuid.v4()

      it 'should return correct error on missing version', (done) ->
        req =
          params: {projectId:projectId}
          body:
            files: newFiles
            projectName: projectName

        res.onEnd = (_body) ->
          assert.equal res.statusCode, 500
          assert.ok _body
          result = JSON.parse _body
          assert.ok result.error, "Body #{body} doesn't have error property."
          assert.equal result.error.type, errorType.OUT_OF_DATE
          done()
        dementorController.createProject req, res

      it 'should return correct error on too old version', (done) ->
        req =
          params: {projectId:projectId}
          body:
            files: newFiles
            projectName: projectName
            version: '0.0.10'

        res.onEnd = (_body) ->
          assert.equal res.statusCode, 500
          assert.ok _body
          result = JSON.parse _body
          assert.ok result.error, "Body #{body} doesn't have error property."
          assert.equal result.error.type, errorType.OUT_OF_DATE
          done()
        dementorController.createProject req, res

      it "should return warning on too old nodejs version", (done) ->
        req =
          params: {projectName: projectName}
          body:
            files: newFiles
            projectName: projectName
            version: minDementorVersion
            nodeVersion: '0.4.0'

        res.onEnd = (_body) ->
          assert.equal res.statusCode, 200
          assert.ok _body
          result = JSON.parse _body
          assert.isFalse result.error?, "Should not return an error."
          assert.ok result.warning, "Body #{_body} doesn't have warning property."
          done()

        dementorController.createProject req, res

      #Making tests pending until we can mock Mongoose and test errors.
      it "returns an error"
      it "returns an error with the correct type"
      #it "returns an error", ->
        #assert.ok result.error, "Body #{body} doesn't have error property."
      #it "returns an error with the correct type", ->
        #assert.equal result.error.type, errorType.DATABASE_ERROR

  describe "create project with multiple tunnels", (done)->
    tunnels = [
          {
            name: "app"
            local: 3000
            remote: 45012
          }

          {
            name: "terminal"
            local: 9490
            remote: 32809
          }
        ]
    req =
      body:
        files: newFiles
        projectName: "multipleTunnels"
        version: minDementorVersion
        tunnels: tunnels

    it "should return local and remote ports for all tunnels passed in", (done)->
      res = new MockResponse
      res.onEnd = (_body) ->
        assert.ok _body
        body = _body
        result = JSON.parse _body
        assert.ok result.project.tunnels
        assert.deepEqual result.project.tunnels, tunnels
        done()

       dementorController.createProject req, res
