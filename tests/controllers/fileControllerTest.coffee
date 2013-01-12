assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'
request = require "request"

FileController = require '../../controllers/fileController'
{ServiceKeeper} = require "../../ServiceKeeper.coffee"
{Settings} = require 'madeye-common'
{MockDb} = require '../mock/MockMongo'
{MockSocket} = require 'madeye-common'
{messageMaker, messageAction} = require 'madeye-common'


describe 'FileController', ->
  # Acceptance tests -- need app, but need to set SocketServer first.
  socketServer = ServiceKeeper.instance().getSocketServer()
  require '../../app'

  fileController = undefined
  beforeEach ->
    fileController = new FileController

  describe 'on save contents', ->
    fileId = uuid.v4()
    projectId = uuid.v4()
    contents = '''If, in the morning, a kitten
    scampers up and boops your nose, are you dreaming?'''
    objects = socket = null
    before (done) ->

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
        uri: "http://localhost:#{Settings.httpPort}/project/#{projectId}/file/#{fileId}"
        json:
          contents: contents

      request options, (err, _res, _body) ->
        objects.body = _body
        objects.response = _res
        done()

    it "returns a 200", ->
      assert.equal objects.response.statusCode, 200
    it 'should return a non-empty body', ->
      assert.ok objects.body
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
    objects = socket = null
    before (done) ->

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
        uri: "http://localhost:#{Settings.httpPort}/project/#{projectId}/file/#{fileId}"

      request options, (err, _res, _body) ->
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

