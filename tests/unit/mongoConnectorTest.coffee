assert = require 'assert'
uuid = require 'node-uuid'
_ = require 'underscore'
{MockDb} = require '../mock/MockMongo'
{MongoConnection} = require '../../src/mongoConnection'
{DataCenter} = require '../../src/dataCenter'
{errorType} = require 'madeye-common'

assertFilesCorrect = (files, targetFiles, projectId) ->
  assert.equal files.length, targetFiles.length, "Number of files incorrect."
  targetMap = {}
  targetMap[file.path] = file for file in targetFiles
  for file in files
    assert.ok file._id
    assert.equal file.projectId, projectId if projectId
    targetFile = targetMap[file.path]
    assert.ok targetFile
    assert.equal file.isDir, targetFile.isDir


describe 'DataCenter', ->
  describe 'with mockDb', ->
    MongoConnection.instance = (errorHandler) ->
      self = this
      connector = new MongoConnection errorHandler
      connector.Db = this.mockDb
      return connector

    newFiles = [
      { path:'file1', isDir:false },
      { path:'dir1', isDir:true },
      { path:'dir1/file2', isDir:false }
    ]

    describe 'close project', ->
      projectId = project = null
      dataCenter = null
      mockDb = null

      before ->
        projectId = uuid.v4()
        project =
          _id: projectId
          name: 'nerzo'
          opened: false
        mockDb = new MockDb
        MongoConnection.mockDb = mockDb
        dataCenter = new DataCenter
        mockDb.load DataCenter.PROJECT_COLLECTION, project

      it 'should set project.opened=false', (done) ->
        dataCenter.closeProject projectId, (err) ->
          assert.equal err, null
          dbProj = mockDb.collections[DataCenter.PROJECT_COLLECTION].get projectId
          assert.equal dbProj.opened, false
          done()

      it 'should not throw an error if project does not exist', (done) ->
        dataCenter.closeProject uuid.v4(), (err) ->
          assert.equal err, null
          done()

    describe 'refreshProject', ->
      projectId = project = returnedProject = null
      dataCenter = null
      file1Id = otherProjectId = null
      mockDb = null


      before ->
        projectId = uuid.v4()
        otherProjectId = uuid.v4()
        project =
          _id: projectId
          name: 'nerzo'
          opened: false
        mockDb = new MockDb
        mockDb.load DataCenter.PROJECT_COLLECTION, project
        #Load with extraneous file
        mockDb.load DataCenter.FILES_COLLECTION,
          _id: uuid.v4()
          projectId: otherProjectId
        MongoConnection.mockDb = mockDb
        dataCenter = new DataCenter

      describe "should return project", ->
        before (done) ->
          project.opened = false
          dataCenter.refreshProject projectId, [], (err, result) ->
            assert.equal err, null, "There should be no error, but got #{JSON.stringify err}"
            returnedProject = result.project
            done()

        it 'correctly', ->
          assert.ok returnedProject
          assert.deepEqual returnedProject, project

        it 'and should set project.opened=true', ->
          assert.ok returnedProject.opened
          assert.equal returnedProject.opened, true
          dbProj = mockDb.collections[DataCenter.PROJECT_COLLECTION].get projectId
          assert.ok dbProj.opened

      describe 'should update files and', ->
        returnedFiles = null

        before (done) ->
          project.opened = false
          #clean out old project files
          mockDb.cleanProjectFiles projectId
          file1Id = uuid.v4()
          oldFiles = [
            { _id: file1Id, path:'file1', isDir:false, projectId: projectId },
            { _id: uuid.v4(), path:'dirA', isDir:true, projectId: projectId },
            { _id: uuid.v4(), path:'dirA/file2', isDir:false, projectId: projectId }
          ]
          for file in oldFiles
            mockDb.load DataCenter.FILES_COLLECTION, file

          dataCenter.refreshProject projectId, newFiles, (err, proj) ->
            returnedFiles = proj.files
            done()

        it 'should return completed submitted files', ->
          assert.ok returnedFiles
          assertFilesCorrect returnedFiles, newFiles, projectId

        it 'should return correct id for extant file', ->
          file = _.find returnedFiles, (f) ->
            f.path = 'file1'
          assert.equal file._id, file1Id

        it 'should update project files to the new files', ->
          dbFiles = mockDb.getProjectFiles projectId
          assertFilesCorrect dbFiles, newFiles

        it 'should not delete files for other projects', ->
          otherFiles = mockDb.getProjectFiles otherProjectId
          assert.ok otherFiles
          assert.equal otherFiles.length, 1



      it 'should callback an error on crudError', (done) ->
        mockDb.collections[DataCenter.PROJECT_COLLECTION].crudError = new Error 'Cannot open collection'
        project.opened = false
        dataCenter.refreshProject projectId, newFiles, (err, proj) ->
          assert.ok err
          assert.equal err.type, errorType.DATABASE_ERROR
          assert.equal proj, null
          #FIXME: Terrible hack.  We should move it to afterEach or something
          delete mockDb.collections[DataCenter.PROJECT_COLLECTION].crudError
          done()

      it 'should throw an error if the project does not exist', (done) ->
        project.opened = false
        dataCenter.refreshProject uuid.v4(), newFiles, (err, proj) ->
          assert.ok err
          assert.equal err.type, errorType.MISSING_OBJECT
          assert.equal proj, null
          done()

    describe 'createProject', ->
      mockDb = null
      projectName = 'kwin'
      result = null

      before (done) ->
        mockDb = new MockDb
        MongoConnection.mockDb = mockDb
        dataCenter = new DataCenter
        dataCenter.createProject projectName, newFiles, (err, theResult) ->
          assert.equal err, null
          assert.ok theResult
          result = theResult
          done()
      
      it 'should return the project', ->
        assert.ok result.project
        assert.equal result.project.name, projectName
        assert.ok result.project._id
        assert.equal result.project.opened, true

      it 'should create the project', ->
        projectId = result.project._id
        dbProject = mockDb.collections[DataCenter.PROJECT_COLLECTION].get projectId
        assert.deepEqual dbProject, result.project

      it 'should return the correct files', ->
        assertFilesCorrect result.files, newFiles, result.project._id


    describe 'addFiles', ->
      mockDb = projectId = null
      dataCenter = null

      before ->
        mockDb = new MockDb
        MongoConnection.mockDb = mockDb
        dataCenter = new DataCenter

      beforeEach ->
        projectId = uuid.v4()

      it 'should add new files to the db', (done) ->
        dataCenter.addFiles newFiles, projectId, (err, result) ->
          assert.equal err, null
          assert.ok result
          assertFilesCorrect result, newFiles
          done()

      it 'should not duplicate existing files to the db', (done) ->
        file1Id = uuid.v4()
        file1 = {_id:file1Id, projectId:projectId, isDir: false, path:'file1'}
        mockDb.load DataCenter.FILES_COLLECTION, file1
        dataCenter.addFiles newFiles, projectId, (err, result) ->
          console.log "AddFiles result", result
          assert.equal err, null
          assert.ok result
          files = _.reject newFiles, (file) ->
            file.path == file1.path
          files.push file1
          assertFilesCorrect result, files
          done()

  describe 'with real db', ->