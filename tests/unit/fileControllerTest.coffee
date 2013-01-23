assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'

FileController = require '../../src/fileController'
{ServiceKeeper} = require "../../ServiceKeeper.coffee"
{Settings} = require 'madeye-common'

describe 'fileController', ->
  ServiceKeeper.reset()
  fileController = undefined
  beforeEach ->
    fileController = new FileController

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
      fileController.dementorChannel =
        saveFile: sinon.spy()

      fileController.saveFile req, res
      callValues = fileController.dementorChannel.saveFile.getCall(0).args
      assert.equal PROJECT_ID, callValues[0]
      message = callValues[1]
      #console.log message
      assert.equal callValues[1], FILE_ID
      assert.equal callValues[2], FILE_CONTENTS

    it "should return a confirmation when there are no problems", ->
      fileController.dementorChannel =
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
    it 'should send a getFile message to dementorChanel'
    it 'should return the body on success'
    it 'should return a 500 if there is an error communicating with dementor'
