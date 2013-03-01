assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'
{Azkaban} = require '../../src/azkaban'

FileController = require '../../src/fileController'
MockResponse = require '../mock/mockResponse'

describe 'fileController', ->
  Azkaban.initialize()
  azkaban = Azkaban.instance()
  fileController = undefined

  beforeEach ->
    fileController = new FileController
    azkaban.setService 'fileController', fileController

  describe 'saveFile', ->
    FILE_CONTENTS = "a riveting text"

    PROJECT_ID = 7
    FILE_ID = 1

    req =
      params:
        projectId: PROJECT_ID
        fileId: FILE_ID
      body:
        contents: FILE_CONTENTS

    res =
      header: ->


    it "should send a save file message to the socket server", ->
      azkaban.setService 'dementorChannel', saveFile: sinon.spy()

      fileController.saveFile req, res
      callValues = azkaban.dementorChannel.saveFile.getCall(0).args
      assert.equal PROJECT_ID, callValues[0]
      message = callValues[1]
      #console.log message
      assert.equal callValues[1], FILE_ID
      assert.equal callValues[2], FILE_CONTENTS

    it "should return a confirmation when there are no problems", ->
      azkaban.setService 'dementorChannel',
        saveFile: (projectId, fileId, contents, callback)->
          callback null

      fileController.request =
        get: (url, callback)->
#         TODO use process.nextTick here
          callback(null, {}, FILE_CONTENTS)

      fakeResponse =
        send: sinon.spy()
        header: ->
        statusCode: 200
      fileController.saveFile req, fakeResponse
      assert.ok fakeResponse.send.called
      callValues = fakeResponse.send.getCall(0).args
      message = JSON.parse callValues[0]
      assert.equal message.projectId, PROJECT_ID
      assert.equal message.fileId, FILE_ID
      assert message.saved

    it "should return a 500 if there is an error communicating with dementor"


  describe 'getFile', ->
    hitDementorChannel = false
    hitBolideClient = false
    before (done) ->
      azkaban.setService "dementorChannel",
        getFileContents: (projectId, fileId, callback)->
          hitDementorChannel = true
          callback null, "FAKE CONTENTS"
      fileController.bolideClient =
        setDocumentContents: (docId, contents, reset=false, callback) ->
          hitBolideClient = true
          callback null

      res = new MockResponse
      res.end = ->
        done()
      fileController.getFile
        params:
          fileId: "FILE_ID"
          projectId: "PROJECT_ID"
        , res

    it 'should send a getFile message to dementorChanel', ->
        assert.isTrue hitDementorChannel
    it 'should send open a shareJS document', ->
        assert.isTrue hitBolideClient

    it 'should return a 200 on success'
    it 'should return a 500 if there is an error communicating with dementor'
