assert = require 'assert'
uuid = require 'node-uuid'
_ = require 'underscore'
{Settings} = require 'madeye-common'
{MongoConnection} = require '../../src/mongoConnection'
{MockDb} = require '../mock/MockMongo'
{ServiceKeeper} = require '../../ServiceKeeper'
{DataCenter} = require '../../src/dataCenter'
{errorType} = require 'madeye-common'
testUtils = require '../util/testUtils'

assertFilesCorrect = testUtils.assertFilesCorrect

describe 'DataCenter', ->
  describe 'with mockDb', ->
    ServiceKeeper.reset()

    newFiles = [
      { path:'file1', isDir:false },
      { path:'dir1', isDir:true },
      { path:'dir1/file2', isDir:false }
    ]

    #TODO: Extract this to testUtils.coffee
    refreshDb = (proj, files = []) ->
      Settings.mockDb = true
      newMockDb = new MockDb
      newMockDb.load DataCenter.PROJECT_COLLECTION, proj
      for file in files
        newMockDb.load DataCenter.FILES_COLLECTION, file
      ServiceKeeper.instance().Db = newMockDb
      return newMockDb

    describe 'close project', ->
      projectId = null
      mockDb = null

      before ->
        projectId = uuid.v4()
        project =
          _id: projectId
          name: 'nerzo'
          opened: false
        mockDb = refreshDb project

      it 'should set project.opened=false', (done) ->
        dataCenter = new DataCenter
        dataCenter.closeProject projectId, (err) ->
          assert.equal err, null
          dbProj = mockDb.collections[DataCenter.PROJECT_COLLECTION].get projectId
          assert.equal dbProj.opened, false
          done()

      it 'should not throw an error if project does not exist', (done) ->
        dataCenter = new DataCenter
        dataCenter.closeProject uuid.v4(), (err) ->
          assert.equal err, null
          done()

    describe 'refreshProject', ->
      projectId = project = returnedProject = null
      file1Id = otherProjectId = null
      mockDb = null
      projectName = 'nerzo'

      newProject = (projId) ->
        _id: projId
        name: projectName
        opened: false

      describe "should return project", ->
        before (done) ->
          projectId = uuid.v4()
          project = newProject projectId
          mockDb = refreshDb project
          dataCenter = new DataCenter
          proj = {projectId:projectId, projectName:projectName}
          dataCenter.refreshProject proj, [], (err, result) ->
            assert.equal err, null, "There should be no error, but got #{JSON.stringify err}"
            returnedProject = result.project
            done()

        it 'correctly', ->
          assert.ok returnedProject
          #To test equality, set the opened=true
          projectCopy = _.clone project
          projectCopy.opened = true
          assert.deepEqual returnedProject, projectCopy

        it 'and should set project.opened=true', ->
          assert.ok returnedProject.opened
          assert.equal returnedProject.opened, true
          dbProj = mockDb.collections[DataCenter.PROJECT_COLLECTION].get projectId
          assert.ok dbProj.opened

      describe 'should update files and', ->
        returnedFiles = null

        before (done) ->
          projectId = uuid.v4()
          project = newProject projectId

          file1Id = uuid.v4()
          otherProjectId = uuid.v4()
          oldFiles = [
            { _id: file1Id, path:'file1', isDir:false, projectId: projectId },
            { _id: uuid.v4(), path:'dirA', isDir:true, projectId: projectId },
            { _id: uuid.v4(), path:'dirA/file2', isDir:false, projectId: projectId },
            { _id: uuid.v4(), path:'test.txt', isDir:false, projectId: otherProjectId }
          ]

          mockDb = refreshDb project, oldFiles

          dataCenter = new DataCenter
          newProj = {projectId:projectId, projectName:projectName}
          dataCenter.refreshProject newProj, newFiles, (err, result) ->
            returnedFiles = result.files
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

      # Test errors
      it 'should callback an error on crudError', (done) ->
        projectId = uuid.v4()
        project = newProject projectId
        mockDb = refreshDb project
        mockDb.collections[DataCenter.PROJECT_COLLECTION].crudError = new Error 'Cannot open collection'
        dataCenter = new DataCenter
        newProj = {projectId:projectId, projectName:projectName}
        dataCenter.refreshProject newProj, newFiles, (err, proj) ->
          assert.ok err
          assert.equal err.type, errorType.DATABASE_ERROR
          assert.equal proj, null
          #FIXME: Terrible hack.  We should move it to afterEach or something
          delete mockDb.collections[DataCenter.PROJECT_COLLECTION].crudError
          done()

      describe 'without existing project', ->
        result = newProjectId = null
        before (done) ->
          projectId = uuid.v4()
          project = newProject projectId
          mockDb = refreshDb project
          dataCenter = new DataCenter
          newProjectId = uuid.v4()
          newProj = {projectId:newProjectId, projectName:projectName}
          dataCenter.refreshProject newProj, newFiles, (err, _result) ->
            assert.equal err, null
            result = _result
            done()

        it 'should create the project', ->
          assert.ok result.project
          assert.equal result.project.name, projectName
          assert.ok result.project._id
          assert.equal result.project._id, newProjectId
          assert.equal result.project.opened, true

        it 'should create the project', ->
          projId = result.project._id
          dbProject = mockDb.collections[DataCenter.PROJECT_COLLECTION].get projId
          assert.deepEqual dbProject, result.project

        it 'should return the correct files', ->
          assertFilesCorrect result.files, newFiles, result.project._id

    describe 'createProject', ->
      mockDb = null
      projectName = 'kwin'
      result = null

      before (done) ->
        mockDb = refreshDb()
        dataCenter = new DataCenter
        newProj = {projectName:projectName}
        dataCenter.createProject newProj, newFiles, (err, theResult) ->
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

      before ->
        mockDb = refreshDb()

      beforeEach ->
        projectId = uuid.v4()

      it 'should add new files to the db', (done) ->
        dataCenter = new DataCenter
        dataCenter.addFiles newFiles, projectId, (err, result) ->
          assert.equal err, null
          assert.ok result
          assertFilesCorrect result, newFiles
          done()

      it 'should not duplicate existing files to the db', (done) ->
        file1Id = uuid.v4()
        file1 = {_id:file1Id, projectId:projectId, isDir: false, path:'file1'}
        mockDb.load 'files', file1
        dataCenter = new DataCenter
        dataCenter.addFiles newFiles, projectId, (err, result) ->
          #console.log "AddFiles result", result
          assert.equal err, null
          assert.ok result
          files = _.reject newFiles, (file) ->
            file.path == file1.path
          files.push file1
          assertFilesCorrect result, files
          done()

  describe 'with real db', ->
    ServiceKeeper.reset()
    Settings.mockDb = false
