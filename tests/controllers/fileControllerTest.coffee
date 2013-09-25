assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'
request = require "request"
{Azkaban} = require '../../src/azkaban'
FileController = require '../../src/fileController'
{Project, File} = require '../../src/models'
{Settings} = require 'madeye-common'
{MockDb} = require '../mock/MockMongo'
{MockSocket} = require 'madeye-common'
{messageMaker, messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
server = require "../../server"
sharejs = require('share').client


describe 'FileController (functional)', ->
  server.listen()

  #TODO: Vestigial code, can be removed.
  fileController = undefined
  beforeEach ->
    fileController = new FileController

  describe 'on save contents', ->
    fileId = uuid.v4()
    projectId = uuid.v4()
    contents = '''If, in the morning, a kitten
    scampers up and boops your nose, are you dreaming?'''

    it 'should return an error', (done) ->
      fileId = uuid.v4()
      options =
        method: "PUT"
        uri: "http://localhost:#{Settings.azkabanPort}/project/#{projectId}/file/#{fileId}"
        json:
          contents: contents

      request options, (err, _res, _body) ->
        assert.equal _res.statusCode, 500
        assert.ok _body.error
        done()

