assert = require 'assert'
uuid = require 'node-uuid'
{MockSocket, SocketServer, messageMaker} = require 'madeye-common'
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

  describe "on receiving message with unknown action", ->
    it "should respond with appropriate error", (done) ->
      message = messageMaker.requestFileMessage uuid.v4()
      channel.route message, (err, replyMsg) ->
        assert.equal null, replyMsg
        assert.ok err
        assert.equal err.type, errorType.UNKNOWN_ACTION
        done()

  describe "with mockDb", ->

    describe "on receiving addFiles message", ->
      message = null
      mockDb = null

      #TODO: Extract this to testUtils.coffee
      refreshDb = (proj, files = []) ->
        Settings.mockDb = true
        newMockDb = new MockDb
        newMockDb.load DataCenter.PROJECT_COLLECTION, proj
        for file in files
          newMockDb.load DataCenter.FILES_COLLECTION, file
        ServiceKeeper.instance().Db = newMockDb
        return newMockDb

      before ->
        message = messageMaker.addFilesMessage [
          {path:'foo/bar/file1', isDir:false },
          {path:'foo/bar/dir1', isDir:true },
          {path:'foo/bar/dir1/file2', isDir:false }
        ]
        message.projectId = uuid.v4()

      beforeEach ->
        mockDb = refreshDb()

      it "should add _id field", (done) ->
        channel.route message, (err, replyMsg) ->
          assert.equal null, err
          assert.ok replyMsg?.data?.files
          assert.ok file._id, "File should have been given _id" for file in replyMsg.data.files
          done()

      it "should callback error if Mongo returns an error", (done) ->
        mockDb.openError = new Error "Cannot open DB"
        channel.route message, (err, replyMsg) ->
          assert.equal null, replyMsg
          assert.ok err
          assert.equal err.type, errorType.DATABASE_ERROR
          done()

