_ = require 'underscore'
assert = require('chai').assert
uuid = require 'node-uuid'
{MockSocket} = require 'madeye-common'
{DementorChannel} = require '../../src/dementorChannel'
{Azkaban} = require '../../src/azkaban'
BolideClient = require '../../src/bolideClient'
FileSyncer = require '../../src/fileSyncer'
{Project, File} = require '../../src/models'
{messageAction} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
async = require 'async'
sharejs = require('share').client
{Settings} = require 'madeye-common'



describe "DementorChannel", ->
  Azkaban.initialize()
  azkaban = Azkaban.instance()
  azkaban.setService 'bolideClient', new BolideClient
  azkaban.setService 'fileSyncer', new FileSyncer

  setupProject = (projectName, objects, callback) ->
    if 'function' == typeof objects
      callback = objects
      objects = {}
    channel = new DementorChannel()
    azkaban.setService 'dementorChannel', channel
    project = new Project name: projectName

    project.save (err) ->
      assert.equal err, null
      projectId = objects.projectId = project._id

      mockSocket = objects.mockSocket = new MockSocket
      channel.attach mockSocket
      mockSocket.trigger messageAction.HANDSHAKE, projectId, (err) ->
        assert.isNull err#, "Error should be null: #{err.message}"

        objects.files = files = [
          {path:'file1', orderingPath:'file1', projectId: projectId, isDir:false, modified: true, lastOpened: Date.now()},
          {path:'dir1', orderingPath:'dir1', projectId: projectId, isDir:true },
          {path:'dir1/file2', orderingPath:'dir1 file2', projectId: projectId, isDir:false, lastOpened: Date.now() }
          {path:'dir1/file3', orderingPath:'dir1 file3', projectId: projectId, isDir:false }
        ]
        fileMap = objects.fileMap = {}
        async.each files, (f, cb) ->
          File.create f, (err, file) ->
            fileMap[file.path] = file
            cb (err)
        , (err) ->
          callback()

  describe "on receiving localFilesAdded message", ->
    objects = {}
    channel = null
    data = null

    beforeEach (done) ->
      setupProject 'swansa', objects, done

    it "should add _id field", (done) ->
      data =
        projectId: objects.projectId
        files: objects.files
      objects.mockSocket.trigger messageAction.LOCAL_FILES_ADDED, data, (err, files) ->
        assert.equal null, err
        assert.ok files
        assert.ok file._id, "File should have been given _id" for file in files
        done()

    it 'should not overwrite existing files', (done) ->
      file = objects.fileMap['file1']
      newFile = _.pick file, 'path', 'orderingPath', 'projectId', 'isDir', 'mtime', 'modified'
      data =
        projectId: objects.projectId
        files: [newFile]
      objects.mockSocket.trigger messageAction.LOCAL_FILES_ADDED, data, (err, files) ->
        assert.equal null, err
        assert.ok files
        savedFile = files[0]
        assert.ok savedFile
        assert.equal savedFile._id, file._id, "File should keep original file id"
        done()


    #Seems better to log and not error out in this case...
    it 'should ignore nulls in files', (done) ->
      data =
        projectId : objects.projectId
        files : [null]
      objects.mockSocket.trigger messageAction.LOCAL_FILES_ADDED, data, (err, result) ->
        assert.isNull err
        done()

    it 'should respond with error when files=null is given', (done) ->
      data =
        projectId : objects.projectId
        files : null
      objects.mockSocket.trigger messageAction.LOCAL_FILES_ADDED, data, (err, result) ->
        assert.ok err
        assert.equal err.type, errorType.MISSING_PARAM
        done()

    #TODO commented out until we can mock mongoose to give errors.
    it "should callback error if Mongo returns an error"
    #it "should callback error if Mongo returns an error", (done) ->
      #mockDb.openError = new Error "Cannot open DB"
      #mockSocket.trigger messageAction.ADD_FILES, data, (err, files) ->
        #assert.equal null, files
        #assert.ok err
        #assert.equal err.type, errorType.DATABASE_ERROR
        #done()

  describe "on receiving localFilesRemoved message", ->
    objects = {}

    beforeEach (done) ->
      setupProject 'liskon', objects, done

    it 'should delete a single file', (done) ->
      file = objects.fileMap['dir1/file2']
      data =
        files: [file]
      objects.mockSocket.trigger messageAction.LOCAL_FILES_REMOVED, data, (err, result) ->
        assert.isNull err
        File.findById file._id, (err, doc) ->
          assert.isNull err
          assert.isNull doc
          done()

    it 'should respond with message when file is modified', (done) ->
      file = objects.fileMap['file1']
      data =
        files: [file]
      objects.mockSocket.trigger messageAction.LOCAL_FILES_REMOVED, data, (err, result) ->
        assert.isNull err
        assert.equal result.action, messageAction.WARNING
        assert.ok result.message
        File.findById file._id, (err, doc) ->
          assert.isNull err
          assert.equal doc.path, file.path
          assert.isTrue doc.modified
          done()
    
    it 'should respond with error when files=[null] is given', (done) ->
      data =
        projectId : 'abf231b8-8344-43d9-89b6-9b4df627fab6'
        files : [null]
      objects.mockSocket.trigger messageAction.LOCAL_FILES_REMOVED, data, (err, result) ->
        assert.ok err
        assert.equal err.type, errorType.INVALID_PARAM
        done()

    it 'should respond with error when files=null is given', (done) ->
      data =
        projectId : 'abf231b8-8344-43d9-89b6-9b4df627fab6'
        files : null
      objects.mockSocket.trigger messageAction.LOCAL_FILES_REMOVED, data, (err, result) ->
        assert.ok err
        assert.equal err.type, errorType.MISSING_PARAM
        done()

    it 'should respond with correct error when unknown fileId is given', (done) ->
      data =
        projectId : 'abf231b8-8344-43d9-89b6-9b4df627fab6'
        files : [{_id:uuid.v4(), projectId:objects.projectId}]
      objects.mockSocket.trigger messageAction.LOCAL_FILES_REMOVED, data, (err, result) ->
        assert.ok err
        assert.equal err.type, errorType.NO_FILE
        done()


  describe "on receiving localFileSaved message", ->
    objects = {}

    beforeEach (done) ->
      setupProject 'nerzo', objects, done

    it 'should have the right body in shareJs', (done) ->
      file = objects.fileMap['dir1/file2']
      contents = "Rarrryys"
      data =
        contents: contents
        file: file
      objects.mockSocket.trigger messageAction.LOCAL_FILE_SAVED, data, (err, result) ->
        assert.isNull err
        sharejs.open file._id, 'text2', "#{Settings.bolideUrl}/channel", (error, doc) ->
          assert.isNull error
          assert.equal doc.getText(), contents
          done()

    #TODO: Break this up into a block with before
    it 'should respond with message when file is modified', (done) ->
      file = objects.fileMap['file1']
      contents = "Rarrryyasdfads"
      data =
        contents: contents
        file: file
      objects.mockSocket.trigger messageAction.LOCAL_FILE_SAVED, data, (err, result) ->
        assert.isNull err
        assert.ok result, "Should return a result."
        assert.equal result.action, messageAction.WARNING
        assert.ok result.message
        File.findById file._id, (err, doc) ->
          assert.isNull err
          assert.isTrue doc.modified_locally
          sharejs.open file._id, 'text2', "#{Settings.bolideUrl}/channel", (error, doc) ->
            assert.isNull error
            assert.notEqual doc.getText(), contents
            done()

    it 'should do nothing when file is unopened', (done) ->
      file = objects.fileMap['dir1/file3']
      contents = "Rarrmustafafads"
      data =
        contents: contents
        file: file
      objects.mockSocket.trigger messageAction.LOCAL_FILE_SAVED, data, (err, result) ->
        assert.isNull err
        assert.isNull result
        File.findById file._id, (err, doc) ->
          assert.isNull err
          assert.isFalse doc.modified_locally
          done()

    it 'should respond with correct error when unknown fileId is given', (done) ->
      data =
        projectId : objects.projectId
        contents: 'whatever#$!'
        file : [{_id:uuid.v4(), projectId:objects.projectId}]
      objects.mockSocket.trigger messageAction.LOCAL_FILE_SAVED, data, (err, result) ->
        assert.ok err
        assert.equal err.type, errorType.INVALID_PARAM
        done()

    it 'should respond with correct error when no file is given', (done) ->
      data =
        projectId : objects.projectId
        contents: 'whatever#$!'
      objects.mockSocket.trigger messageAction.LOCAL_FILE_SAVED, data, (err, result) ->
        assert.ok err
        assert.equal err.type, errorType.INVALID_PARAM
        done()

    it 'should respond with correct error when no contents is given', (done) ->
      data =
        projectId : objects.projectId
        file : [{_id:uuid.v4(), projectId:objects.projectId}]
      objects.mockSocket.trigger messageAction.LOCAL_FILE_SAVED, data, (err, result) ->
        assert.ok err
        assert.equal err.type, errorType.INVALID_PARAM
        done()


  describe 'destroy', ->
    it 'should disconnect all live sockets'
    it 'should close all live projects'

  describe 'on handshake', ->
    projectId = null
    channel = null
    mockSocket = null
    before (done) ->
      mockSocket = new MockSocket
      channel = new DementorChannel()
      channel.attach mockSocket

      project = new Project
        name: 'onkik'
        closed: true
      project.save (err) ->
        assert.equal err, null
        projectId = project._id
        done()
    it 'should open project', (done) ->
      mockSocket.trigger messageAction.HANDSHAKE, projectId, ->
        Project.findOne {_id: projectId}, (err, proj) ->
          assert.equal err, null
          assert.equal proj.closed, false
          done()

  describe 'on disconnect', ->
    projectId = project = null
    channel = null
    mockSocket = null
    before (done) ->
      mockSocket = new MockSocket
      channel = new DementorChannel()
      channel.attach mockSocket

      project = new Project
        name: 'foblub'
        closed: false
      project.save (err) ->
        assert.equal err, null
        projectId = project._id
        done()

    beforeEach (done) ->
      project.update {$set: {closed: false}}, done

    it 'should close project after 5 seconds'

    it 'should not close project if new socket is attached quickly', (done) ->
      channel.closeProject = (projectId, callback) ->
        assert.fail "Should not call closeProject."
      mockSocket.trigger 'disconnect'
      setTimeout (->
        mockSocket.trigger messageAction.HANDSHAKE, projectId, (err) ->
          Project.findOne {_id: projectId}, (err, proj) ->
            assert.equal err, null
            assert.equal proj.closed, false
            done()
      ), 100



  describe 'closeProject', ->
    projectId = null
    channel = null
    before (done) ->
      channel = new DementorChannel()
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
    
