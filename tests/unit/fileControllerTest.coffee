assert = require("chai").assert
uuid = require 'node-uuid'
sinon = require 'sinon'
{Azkaban} = require '../../src/azkaban'
FileSyncer = require '../../src/fileSyncer'
FileController = require '../../src/fileController'
MockResponse = require '../mock/mockResponse'
{Project, File} = require '../../src/models'
{crc32} = require 'madeye-common'

describe 'fileController', ->
  Azkaban.initialize()
  azkaban = Azkaban.instance()
  azkaban.setService 'fileSyncer', new FileSyncer
  fileController = undefined

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

      fileController = new FileController
      azkaban.setService 'fileController', fileController

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
    fakeContents = "FAKE CONTENTS"
    response = null
    before (done) ->
      azkaban.setService "dementorChannel",
        getFileContents: (projectId, fileId, callback)->
          hitDementorChannel = true
          callback null, fakeContents
      azkaban.setService "bolideClient",
        setDocumentContents: (docId, contents, reset=false, callback) ->
          hitBolideClient = true
          callback null

      response = new MockResponse
      response.end = (_body) ->
        this.body = JSON.parse _body
        done()

      projectId = uuid.v4()
      file = new File path:'foo/bar.txt', projectId:projectId, isDir:false
      fileId = file._id

      fileController = new FileController
      azkaban.setService 'fileController', fileController

      File.create file, (err) ->
        assert.isNull err
        fileController.getFile
          params:
            fileId: fileId
            projectId: projectId
          , response

    it 'should send a getFile message to dementorChanel', ->
      assert.isTrue hitDementorChannel
    it 'should send open a shareJS document', ->
      assert.isTrue hitBolideClient

    it 'should return a 200 on success', ->
      assert.equal response.statusCode, 200

    it 'should return correct checksum', ->
      console.log "Found response body #{typeof response.body}", response.body
      assert.equal response.body.checksum, crc32 fakeContents

    it 'should return a 500 if there is an error communicating with dementor'
