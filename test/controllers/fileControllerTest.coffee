assert = require 'assert'
request = require 'request'
uuid = require 'node-uuid'

{ServiceKeeper} = require '../../ServiceKeeper'
{MongoConnector} = require '../../connectors/MongoConnector'
{MockDb} = require '../mock/MockMongo'
{Settings} = require "../../Settings"

describe 'fileController', ->
  describe 'on get info', ->
    fileId = uuid.v4()
    projectId = uuid.v4()
    body = '''without a cat one has to wonder,
      is the world real, or just imgur?'''
    socket = null
    before ->
      mockDb = new MockDb()
      mongoConnector = new MongoConnector(mockDb)
      ServiceKeeper.mongoConnector = mongoConnector

      mockFile = {
        _id: fileId,
        path: 'on/the/road.txt',
        body: body
      }
      mockDb.load 'files', mockFile


      objects = {}
      options =
        method: "GET"
        uri: "http://localhost:#{Settings.httpPort}/project/#{projectId}/file/#{fileId}"
      request options, (err, _res, _body) ->
        #console.log "Found body ", _body
        objects.bodyStr = _body
        try
          objects.body = JSON.parse _body
        catch error
          "Let the test catch this."
        objects.response = _res

    it 'should request id from Mongo'

    it 'should send request message to dementor'



