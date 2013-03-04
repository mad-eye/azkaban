assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'
{Azkaban} = require '../../src/azkaban'

FileController = require '../../src/fileController'
MockResponse = require '../mock/mockResponse'
{Project, File} = require '../../src/models'

describe 'fileController', ->
  Azkaban.initialize()
  azkaban = Azkaban.instance()
  fileController = undefined

  beforeEach ->
    fileController = new FileController
    azkaban.setService 'fileController', fileController

  describe 'saveFile', ->
    FILE_CONTENTS = "a riveting text"

    projectId = uuid.v4()
    fileId = null

    req = null
    res = new MockResponse

    before (done) ->
      file = new File path:'foo/bar.txt', projectId:projectId, isDir:false
      fileId = file._id

      req =
        params:
          projectId: projectId
          fileId: fileId
        body:
          contents: FILE_CONTENTS

      File.create file, (err) ->
        assert.isNull err
        done()



    it "should send a save file message to the socket server", ->
      azkaban.setService 'dementorChannel', saveFile: sinon.spy()

      fileController.saveFile req, res
      callValues = azkaban.dementorChannel.saveFile.getCall(0).args
      assert.equal projectId, callValues[0]
      message = callValues[1]
      #console.log message
      assert.equal callValues[1], fileId
      assert.equal callValues[2], FILE_CONTENTS

    it "should return a confirmation when there are no problems", (done)->
      azkaban.setService 'dementorChannel',
        saveFile: (projectId, fileId, contents, callback)->
          callback null

      fileController.request =
        get: (url, callback)->
#         TODO use process.nextTick here
          callback(null, {}, FILE_CONTENTS)

      fakeResponse = new MockResponse
      fakeResponse.end = (body)->
        message = JSON.parse body
        assert.equal message.projectId, projectId
        assert.equal message.fileId, fileId
        assert message.saved
        done()

      fileController.saveFile req, fakeResponse

    it "should return a 500 if there is an error communicating with dementor"


  describe 'getFile', ->
    hitDementorChannel = false
    hitBolideClient = false
    before (done) ->
      azkaban.setService "dementorChannel",
        getFileContents: (projectId, fileId, callback)->
          hitDementorChannel = true
          callback null, "FAKE CONTENTS"
      azkaban.setService "bolideClient"
        setDocumentContents: (docId, contents, reset=false, callback) ->
          hitBolideClient = true
          callback null

      res = new MockResponse
      res.end = ->
        done()

      projectId = uuid.v4()
      file = new File path:'foo/bar.txt', projectId:projectId, isDir:false
      fileId = file._id
      File.create file, (err) ->
        assert.isNull err

        fileController.getFile
          params:
            fileId: fileId
            projectId: projectId
          , res

    it 'should send a getFile message to dementorChanel', ->
        assert.isTrue hitDementorChannel
    it 'should send open a shareJS document', ->
        assert.isTrue hitBolideClient

    it 'should return a 200 on success'
    it 'should return a 500 if there is an error communicating with dementor'
