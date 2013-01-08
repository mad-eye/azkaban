assert = require 'assert'
uuid = require 'node-uuid'
_ = require 'underscore'
{MockDb} = require '../mock/MockMongo'
{MongoConnector} = require '../../src/mongoConnector'
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


describe 'MongoConnector', ->
  describe 'with mockDb', ->
    mockDb = null
    newFiles = [
      { path:'file1', isDir:false },
      { path:'dir1', isDir:true },
      { path:'dir1/file2', isDir:false }
    ]

    describe 'close project', ->
      projectId = project = null
      mongoConnector = null

      before ->
        projectId = uuid.v4()
        project =
          _id: projectId
          name: 'nerzo'
          opened: false
        mockDb = new MockDb
        mockDb.load MongoConnector.PROJECT_COLLECTION, project
        mongoConnector = new MongoConnector(mockDb)

      it 'should set project.opened=false', (done) ->
        mongoConnector.closeProject projectId, (err) ->
          assert.equal err, null
          dbProj = mockDb.collections[MongoConnector.PROJECT_COLLECTION].get projectId
          assert.equal dbProj.opened, false
          done()

      it 'should not throw an error if project does not exist', (done) ->
        mongoConnector.closeProject uuid.v4(), (err) ->
          assert.equal err, null
          done()

    describe 'refreshProject', ->
      projectId = project = returnedProject = null
      mongoConnector = null
      file1Id = otherProjectId = null


      before ->
        projectId = uuid.v4()
        otherProjectId = uuid.v4()
        project =
          _id: projectId
          name: 'nerzo'
          opened: false
        mockDb = new MockDb
        mockDb.load MongoConnector.PROJECT_COLLECTION, project
        #Load with extraneous file
        mockDb.load MongoConnector.FILES_COLLECTION,
          _id: uuid.v4()
          projectId: otherProjectId
        mongoConnector = new MongoConnector(mockDb)

      describe "should return project", ->
        before (done) ->
          project.opened = false
          mongoConnector.refreshProject projectId, [], (err, result) ->
            assert.equal err, null, "There should be no error, but got #{JSON.stringify err}"
            returnedProject = result.project
            done()

        it 'correctly', ->
          assert.ok returnedProject
          assert.deepEqual returnedProject, project

        it 'and should set project.opened=true', ->
          assert.ok returnedProject.opened
          assert.equal returnedProject.opened, true
          dbProj = mockDb.collections[MongoConnector.PROJECT_COLLECTION].get projectId
          assert.ok dbProj.opened

      describe 'should update files and fweep', ->
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
            mockDb.load MongoConnector.FILES_COLLECTION, file

          mongoConnector.refreshProject projectId, newFiles, (err, proj) ->
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
        mockDb.collections[MongoConnector.PROJECT_COLLECTION].crudError = new Error 'Cannot open collection'
        project.opened = false
        mongoConnector.refreshProject projectId, newFiles, (err, proj) ->
          assert.ok err
          assert.equal err.type, errorType.DATABASE_ERROR
          assert.equal proj, null
          #FIXME: Terrible hack.  We should move it to afterEach or something
          delete mockDb.collections[MongoConnector.PROJECT_COLLECTION].crudError
          done()

      it 'should throw an error if the project does not exist', (done) ->
        project.opened = false
        mongoConnector.refreshProject uuid.v4(), newFiles, (err, proj) ->
          assert.ok err
          assert.equal err.type, errorType.MISSING_OBJECT
          assert.equal proj, null
          done()

    describe 'createProject', ->
      mongoConnector = mockDb = null
      projectName = 'kwin'
      result = null

      before (done) ->
        mockDb = new MockDb
        mongoConnector = new MongoConnector(mockDb)
        mongoConnector.createProject projectName, newFiles, (err, theResult) ->
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
        dbProject = mockDb.collections[MongoConnector.PROJECT_COLLECTION].get projectId
        assert.deepEqual dbProject, result.project

      it 'should return the correct files', ->
        assertFilesCorrect result.files, newFiles, result.project._id


    describe 'addfiles', ->
      mongoConnector = mockDb = projectId = null

      before ->
        mockDb = new MockDb
        mongoConnector = new MongoConnector(mockDb)

      beforeEach ->
        projectId = uuid.v4()

      it 'should add new files to the db', (done) ->
        mongoConnector.addFiles newFiles, projectId, (err, result) ->
          assert.equal err, null
          assert.ok result
          assertFilesCorrect result, newFiles
          done()

      it 'should not duplicate existing files to the db', (done) ->
        file1Id = uuid.v4()
        file1 = {_id:file1Id, projectId:projectId, isDir: false, path:'file1'}
        mockDb.load MongoConnector.FILES_COLLECTION, file1
        mongoConnector.addFiles newFiles, projectId, (err, result) ->
          assert.equal err, null
          assert.ok result
          files = _.reject newFiles, (file) ->
            file.path = file1.path
          files.push file1
          assertFilesCorrect result, files
          done()

    describe "getFilesForProject", ->
      projectId = files = mongoConnector = null
      before ->
        mockDb = new MockDb
        mongoConnector = new MongoConnector(mockDb)
        projectId = uuid.v4()
        files = [
          {_id:uuid.v4(), projectId:projectId, isDir: false, path:'file1'},
          {_id:uuid.v4(), projectId:projectId, isDir: true, path:'dir1'},
          {_id:uuid.v4(), projectId:projectId, isDir: false, path:'dir1/file2'}
        ]

        for file in files
          mockDb.load MongoConnector.FILES_COLLECTION, file
        #Load extraneous file
        mockDb.load MongoConnector.FILES_COLLECTION,
          {_id:uuid.v4(), projectId:uuid.v4(), isDir: false, path:'dir1/file2'}

      it "should get all the files for a project", (done) ->
        mongoConnector.getFilesForProject projectId, (err, results) ->
          assert.equal err, null
          assert.ok results
          assertFilesCorrect
          assert.equal results.length, files.length
          done()

      it "should not get files of another project", (done) ->
        mongoConnector.getFilesForProject uuid.v4(), (err, results) ->
          assert.equal err, null
          assert.ok results
          assert.equal results.length, 0
          done()


  describe 'with real db', ->
