assert = require 'assert'
request = require 'request'
uuid = require 'node-uuid'

{Settings} = require 'madeye-common'
{ChannelMessage} = require 'madeye-common'

{ServiceKeeper} = require '../../ServiceKeeper'
{MongoConnector} = require '../../connectors/MongoConnector'
{MockDb} = require '../mock/MockMongo'
{MockSocket} = require '../mock/MockSocket'

app = require '../../app'

describe 'fileController', ->
  fileId = projectId = body = null
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
          return unless message.action == ChannelMessage.REQUEST_FILE
          @sentMessages ?= []
          @sentMessages.push message
          replyMessage = new ChannelMessage ChannelMessage.REQUEST_FILE,
            replyTo : message.id,
            projectId : projectId,
            data:
              fileId: fileId,
              body: body
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
    



