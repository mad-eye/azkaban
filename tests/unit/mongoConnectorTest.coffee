assert = require 'assert'
uuid = require 'node-uuid'
_ = require 'underscore'
{MockDb} = require '../mock/MockMongo'
{MongoConnector} = require '../../src/mongoConnector'
{errorType} = require 'madeye-common'

describe 'MongoConnector', ->
  describe 'with mockDb', ->
    mockDb = null

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
        #Load with extraneous file
        mockDb.load MongoConnector.FILES_COLLECTION,
          _id: uuid.v4()
          projectId: uuid.v4()
        mongoConnector = new MongoConnector(mockDb)

      beforeEach ->
        mockDb.load MongoConnector.FILES_COLLECTION,
          _id: uuid.v4()
          projectId: projectId
        mockDb.load MongoConnector.FILES_COLLECTION,
          _id: uuid.v4()
          projectId: projectId

        
      
      it 'should return project', (done) ->
        mongoConnector.refreshProject projectId, (err, proj) ->
          assert.equal err, null, "There should be no error, but got #{JSON.stringify err}"
          assert.ok proj
          assert.deepEqual proj, project
          done()

      it 'should set project.opened=true', (done) ->
        mongoConnector.refreshProject projectId, (err, proj) ->
          assert.ok proj.opened
          assert.equal proj.opened, true
          dbProj = mockDb.collections[MongoConnector.PROJECT_COLLECTION].get projectId
          assert.ok dbProj.opened
          done()

      it 'should delete all files for project', (done) ->
        mongoConnector.refreshProject projectId, (err, proj) ->
          files = mockDb.collections[MongoConnector.FILES_COLLECTION].documents
          projectFiles = _.filter files, (file) ->
            file.projectId == projectId
          assert.equal projectFiles.length, 0
          done()

      it 'should not delete files for other projects', (done) ->
        mongoConnector.refreshProject projectId, (err, proj) ->
          files = mockDb.collections[MongoConnector.FILES_COLLECTION].documents
          assert.equal files.length, 1
          done()

      it 'should callback an error on crudError', (done) ->
        mockDb.collections[MongoConnector.PROJECT_COLLECTION].crudError = new Error 'Cannot open collection'
        mongoConnector.refreshProject projectId, (err, proj) ->
          assert.ok err
          assert.equal err.type, errorType.DATABASE_ERROR
          assert.equal proj, null
          #FIXME: Terrible hack.  We should move it to afterEach or something
          delete mockDb.collections[MongoConnector.PROJECT_COLLECTION].crudError
          done()

      it 'should throw an error if the project does not exist', (done) ->
        mongoConnector.refreshProject uuid.v4(), (err, proj) ->
          assert.ok err
          assert.equal err.type, errorType.MISSING_OBJECT
          assert.equal proj, null
          done()

    describe 'createProject', ->
      mongoConnector = mockDb = null
      projectName = 'kwin'
      returnedProject = null

      before (done) ->
        mockDb = new MockDb
        mongoConnector = new MongoConnector(mockDb)
        mongoConnector.createProject projectName, (err, projects) ->
          assert.equal err, null
          assert.ok projects
          returnedProject = projects[0]
          done()
      
      it 'should create the project', ->
        projects = mockDb.collections[MongoConnector.PROJECT_COLLECTION].documents
        console.log "mockDb.projets has documents", projects
        assert.ok _.any projects, (proj) ->
          console.log "Checking #{proj} for name #{projectName}"
          proj.name == projectName


      it 'should return the project', ->
        assert.ok returnedProject
        assert.equal returnedProject.name, projectName

      it 'should set a projectId', ->
        assert.ok returnedProject._id

      it 'should set project.opened=true', ->
        project = mockDb.collections[MongoConnector.PROJECT_COLLECTION].get returnedProject._id
        assert.equal project.opened, true

    describe 'addfiles', ->
      mongoConnector = mockDb = null

      before ->
        mockDb = new MockDb
        mongoConnector = new MongoConnector(mockDb)

      it 'should add new files to the db', (done) ->
        projectId = uuid.v4()
        files = [
          {isDir: false, path:'file1'},
          {isDir: true, path:'dir1'},
          {isDir: false, path:'dir1/file2'}
        ]
        mongoConnector.addFiles files, projectId, (err, result) ->
          assert.equal err, null
          assert.ok result
          assert.equal result.length, files.length
          for file in result
            assert.ok file._id?
            assert.ok file.isDir?
            assert.ok file.path?
          done()

      it 'should not duplicate existing files to the db', (done) ->
        projectId = uuid.v4()
        file1Id = uuid.v4()
        file1 = {_id:file1Id, isDir: false, path:'file1'}
        mockDb.load MongoConnector.PROJECT_COLLECTION, file1
        files = [
          {isDir: false, path:'file1'},
          {isDir: true, path:'dir1'},
          {isDir: false, path:'dir1/file2'}
        ]
        mongoConnector.addFiles files, projectId, (err, result) ->
          assert.equal err, null
          assert.ok result
          assert.equal result.length, files.length
          for file in result
            assert.ok file._id?
            assert.ok file.isDir?
            assert.ok file.path?
            if file.path == 'file1'
              assert.equal file._id, file1Id
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
        console.log "Loaded mockDb.files:", mockDb.collections['files'].documents

      it "should get all the files for a project fweep", (done) ->
        mongoConnector.getFilesForProject projectId, (err, results) ->
          assert.equal err, null
          assert.ok results
          assert.equal results.length, files.length
          done()

      it "should not get files of another project", (done) ->
        mongoConnector.getFilesForProject uuid.v4(), (err, results) ->
          assert.equal err, null
          assert.ok results
          assert.equal results.length, 0
          done()


  describe 'with real db', ->
