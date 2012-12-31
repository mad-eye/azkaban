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
      
      it 'should create the project'

      it 'should return the project'

      it 'should set project.opened=true'


  describe 'with real db', ->
