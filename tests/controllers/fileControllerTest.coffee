assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'
request = require "request"

FileController = require '../../controllers/fileController'
{ServiceKeeper} = require "../../ServiceKeeper.coffee"
{MockDb} = require '../mock/MockMongo'
{MockSocket} = require 'madeye-common'
{messageMaker, messageAction} = require 'madeye-common'

app = require '../../app'

describe 'fileController', ->
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
      console.log message
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

  describe 'on save contents', ->
    fileId = uuid.v4()
    projectId = uuid.v4()
    contents = '''If, in the morning, a kitten
    scampers up and boops your nose, are you dreaming?'''
    objects = socket = socketServer = null
    before (done) ->

      socketServer = ServiceKeeper.getSocketServer()
      socket = new MockSocket {
        onsend: (message) ->
          return unless message.action == messageAction.SAVE_FILE
          @sentMessages ?= []
          @sentMessages.push message
          replyMessage = messageMaker.replyMessage message
          replyMessage.projectId = projectId
          @receivedSaveMessage = true
          setTimeout (=>
            @receive replyMessage
          ), 10
      }
      socketServer.connect socket
      socketServer.attachSocket socket, projectId

      objects = {}
      options =
        method: "PUT"
        uri: "http://localhost:#{app.get('port')}/project/#{projectId}/file/#{fileId}"
        form:
          contents: contents

      console.log "Sending PUT request to", options.uri
      request options, (err, _res, _body) ->
        #console.log "Found body ", _body
        objects.bodyStr = _body
        try
          objects.body = JSON.parse _body
        catch error
          console.log "Unable to parse", _body
          "Let the test catch this."
        objects.response = _res
        done()

    it "returns a 200", ->
      assert.ok objects.response.statusCode == 200
    it "returns valid JSON", ->
      assert.doesNotThrow ->
        JSON.parse(objects.bodyStr)
    it 'should return a non-empty body', ->
      assert.ok objects.body
      console.log "Returned request body", objects.body
    it 'should return a fileId in response body', ->
      assert.equal objects.body.fileId, fileId
    it 'should return a projectId in response body', ->
      assert.equal objects.body.projectId, projectId
    it 'should return a saved=true in response body', ->
      assert.ok objects.body.saved
    it 'should have sent the message to the socket', ->
      assert.ok socket.receivedSaveMessage

    it 'should handle a shut-down dementor gracefully'
    it 'should return an error on a null contents'

  describe 'on get info', ->
    fileId = uuid.v4()
    projectId = uuid.v4()
    body = '''without a cat one has to wonder,
      is the world real, or just imgur?'''
    objects = socket = socketServer = null
    before (done) ->

      socketServer = ServiceKeeper.getSocketServer()
      socket = new MockSocket {
        onsend: (message) ->
          return unless message.action == messageAction.REQUEST_FILE
          @sentMessages ?= []
          @sentMessages.push message
          replyMessage = messageMaker.replyMessage message,
            fileId: fileId,
            body: body
          replyMessage.projectId = projectId
          setTimeout (=>
            @receive replyMessage
          ), 100
      }
      socketServer.connect socket
      socketServer.attachSocket socket, projectId

      objects = {}
      options =
        method: "GET"
        uri: "http://localhost:#{app.get('port')}/project/#{projectId}/file/#{fileId}"

      console.log "Sending request to", options.uri
      request options, (err, _res, _body) ->
        #console.log "Found body ", _body
        objects.bodyStr = _body
        try
          objects.body = JSON.parse _body
        catch error
          console.log "Unable to parse", _body
          "Let the test catch this."
        objects.response = _res
        done()

    it "returns a 200", ->
      assert.ok objects.response.statusCode == 200
    it "returns valid JSON", ->
      assert.doesNotThrow ->
        JSON.parse(objects.bodyStr)
    it 'should return a non-empty body', ->
      assert.ok objects.body
      console.log "Returned file body", objects.body
    it 'should return a fileId in response body', ->
      assert.equal objects.body.fileId, fileId
    it 'should return file body from dementor', ->
      assert.equal objects.body.body, body

    it 'should send request message to dementor', ->
      assert.ok socket.sentMessages
      assert.equal socket.sentMessages.length, 1
    it 'should send message with correct action and fileId', ->
      sentMessage = socket.sentMessages[0]
      assert.equal sentMessage.action, 'requestFile'
      assert.equal sentMessage.fileId, fileId
