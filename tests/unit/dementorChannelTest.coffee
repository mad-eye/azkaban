assert = require 'assert'
uuid = require 'node-uuid'
{MockSocket, messageMaker} = require 'madeye-common'
{DementorChannel} = require '../../src/dementorChannel'
{ServiceKeeper} = require '../../ServiceKeeper'
{MongoConnection} = require '../../src/mongoConnection'
{DataCenter} = require '../../src/dataCenter'
{MockDb} = require '../mock/MockMongo'
{Settings} = require 'madeye-common'
{messageMaker, messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'

#
# Messages are of the form:
# {
#   action: eg addFiles, removeFiles, etc
#   id: uuid of message
#   projectId: uuid of project
#   timestamp: Date timestamp of sending
#   data: JSON object, case specific data
# }

describe "DementorChannel", ->
  channel = null
  before ->
    channel = new DementorChannel()

  describe "with mockDb", ->

    describe "on receiving addFiles message", ->
      data = null
      mockDb = mockSocket = null

      #TODO: Extract this to testUtils.coffee
      refreshDb = (proj, files = []) ->
        Settings.mockDb = true
        newMockDb = new MockDb
        newMockDb.load 'projects', proj
        for file in files
          newMockDb.load 'files', file
        ServiceKeeper.instance().Db = newMockDb
        return newMockDb

      beforeEach ->
        projectId = uuid.v4()
        mockSocket = new MockSocket
        channel.attach mockSocket
        mockSocket.trigger messageAction.HANDSHAKE, projectId
        mockDb = refreshDb()
        data =
          projectId: projectId
          files: [
            {path:'foo/bar/file1', isDir:false },
            {path:'foo/bar/dir1', isDir:true },
            {path:'foo/bar/dir1/file2', isDir:false }
          ]

      it "should add _id field", (done) ->
        mockSocket.trigger messageAction.ADD_FILES, data, (err, files) ->
          assert.equal null, err
          assert.ok files
          assert.ok file._id, "File should have been given _id" for file in files
          done()

      it "should callback error if Mongo returns an error", (done) ->
        mockDb.openError = new Error "Cannot open DB"
        mockSocket.trigger messageAction.ADD_FILES, data, (err, files) ->
          assert.equal null, files
          assert.ok err
          assert.equal err.type, errorType.DATABASE_ERROR
          done()

  describe 'destroy', ->
    it 'should disconnect all live sockets'
    it 'should close all live projects'

  describe 'on disconnect', ->
    it 'should close project'
    it 'should not close project if new socket is attached'
