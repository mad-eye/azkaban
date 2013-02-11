assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'
request = require "request"
{Azkaban} = require '../../src/azkaban'
FileController = require '../../src/fileController'
{Settings} = require 'madeye-common'
{MockDb} = require '../mock/MockMongo'
{MockSocket} = require 'madeye-common'
{messageMaker, messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
server = require "../../server"


describe 'FileController', ->
  # Acceptance tests -- need app, but need to set DementorChannel first
  server.listen()

  dementorChannel = Azkaban.instance().dementorChannel

  fileController = undefined
  beforeEach ->
    fileController = new FileController

  describe 'on save contents', ->
    fileId = uuid.v4()
    projectId = uuid.v4()
    contents = '''If, in the morning, a kitten
    scampers up and boops your nose, are you dreaming?'''
    objects = socket = null
    saveFileMessages = {}
    before (done) ->

      socket = new MockSocket
      socket.onEmit = (action, data, callback) ->
        if action == messageAction.SAVE_FILE
          unless data.fileId && data.contents
            callback errors.new errorType.MISSING_PARAM
            return
          saveFileMessages[data.fileId] = data.contents
          setTimeout (=>
            callback()
          ), 10
            

      dementorChannel.attach socket
      socket.trigger messageAction.HANDSHAKE, projectId

      objects = {}
      options =
        method: "PUT"
        uri: "http://localhost:#{Settings.azkabanPort}/project/#{projectId}/file/#{fileId}"
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
      assert.equal saveFileMessages[fileId], contents

    it 'should handle a shut-down dementor gracefully', (done) ->
      fileId = uuid.v4()
      options =
        method: "PUT"
        uri: "http://localhost:#{Settings.azkabanPort}/project/#{uuid.v4()}/file/#{fileId}"
        json:
          contents: contents

      request options, (err, _res, _body) ->
        assert.equal _res.statusCode, 500
        assert.ok _body.error
        assert.equal _body.error.type, errorType.CONNECTION_CLOSED
        assert.equal saveFileMessages[fileId], null
        done()

    it 'should return an error on a null contents', (done) ->
      fileId = uuid.v4()
      options =
        method: "PUT"
        uri: "http://localhost:#{Settings.azkabanPort}/project/#{projectId}/file/#{fileId}"
        json:
          contents: null

      request options, (err, _res, _body) ->
        assert.equal _res.statusCode, 500
        assert.ok _body.error
        assert.equal _body.error.type, errorType.MISSING_PARAM
        assert.equal saveFileMessages[fileId], null
        done()

  describe 'on get info', ->
    fileId = uuid.v4()
    projectId = uuid.v4()
    body = '''without a cat one has to wonder,
      is the world real, or just imgur?'''
    objects = socket = null
    requestedFiles = {}
    before (done) ->

      socket = new MockSocket
      socket.onEmit = (action, data, callback) ->
        if action == messageAction.REQUEST_FILE
          unless data.fileId
            callback errors.new errorType.MISSING_PARAM
            return
          requestedFiles[data.fileId] = true
          setTimeout (=>
            callback null, body
          ), 10
            
      dementorChannel.attach socket
      socket.trigger messageAction.HANDSHAKE, projectId

      objects = {}
      options =
        method: "GET"
        uri: "http://localhost:#{Settings.azkabanPort}/project/#{projectId}/file/#{fileId}"

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

    it 'should send request message to dementor', ->
      assert.ok requestedFiles[fileId]

