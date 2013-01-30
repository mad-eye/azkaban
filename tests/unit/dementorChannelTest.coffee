assert = require 'assert'
uuid = require 'node-uuid'
{MockSocket, messageMaker} = require 'madeye-common'
{DementorChannel} = require '../../src/dementorChannel'
{ServiceKeeper} = require '../../ServiceKeeper'
{MockDb} = require '../mock/MockMongo'
{Project} = require '../../src/models'
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

  describe "on receiving addFiles message", ->
    data = null
    mockSocket = null
    projectId = null

    beforeEach (done) ->
      project = new Project
        name: 'swansa'

      project.save (err) ->
        assert.equal err, null
        projectId = project._id

        data =
          projectId: projectId
          files: [
            {path:'foo/bar/file1', isDir:false },
            {path:'foo/bar/dir1', isDir:true },
            {path:'foo/bar/dir1/file2', isDir:false }
          ]

        mockSocket = new MockSocket
        channel.attach mockSocket
        mockSocket.trigger messageAction.HANDSHAKE, projectId
        done()

    it "should add _id field", (done) ->
      mockSocket.trigger messageAction.ADD_FILES, data, (err, files) ->
        assert.equal null, err
        assert.ok files
        assert.ok file._id, "File should have been given _id" for file in files
        done()

    it 'should not overwrite existing files'

    #TODO commented out until we can mock mongoose to give errors.
    it "should callback error if Mongo returns an error"
    #it "should callback error if Mongo returns an error", (done) ->
      #mockDb.openError = new Error "Cannot open DB"
      #mockSocket.trigger messageAction.ADD_FILES, data, (err, files) ->
        #assert.equal null, files
        #assert.ok err
        #assert.equal err.type, errorType.DATABASE_ERROR
        #done()

  describe 'destroy', ->
    it 'should disconnect all live sockets'
    it 'should close all live projects'

  describe 'on disconnect', ->
    it 'should close project'
    it 'should not close project if new socket is attached'

  describe 'closeProject', ->
    projectId = null
    before (done) ->
      project = new Project
        name: 'nitfol'
        closed: false
      project.save (err) ->
        assert.equal err, null
        projectId = project._id
        channel.closeProject projectId, done
    it 'should close project', (done) ->
      Project.findOne {_id: projectId}, (err, proj) ->
        assert.equal err, null
        assert.equal proj.closed, true
        done()
    
