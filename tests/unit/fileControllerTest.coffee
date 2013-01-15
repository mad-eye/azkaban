assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'

FileController = require '../../controllers/fileController'
{ServiceKeeper} = require "../../ServiceKeeper.coffee"
{Settings} = require 'madeye-common'

describe 'fileController', ->
  ServiceKeeper.reset()
  fileController = undefined
  beforeEach ->
    fileController = new FileController

  describe 'on save', ->
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
      fileController.socketServer =
        tell: sinon.spy()

      fileController.saveFile req, res
      callValues = fileController.socketServer.tell.getCall(0).args
      assert.equal PROJECT_ID, callValues[0]
      message = callValues[1]
      #console.log message
      assert.equal message.data.fileId, FILE_ID
      assert.equal message.data.contents, FILE_CONTENTS

    it "should return a confirmation when there are no problems", ->
      fileController.socketServer =
        tell: (projectId, message, callback)->
          callback null, "W00T"

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

    it "should return a 500 if there is an error making the message", ->

    it "should return a 500 if there is an error communicating with dementor", ->

    it "should return a 500 if it cannot retrieve the file from bolide", ->


