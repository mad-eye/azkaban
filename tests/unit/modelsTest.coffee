assert = require 'assert'
async = require 'async'
uuid = require 'node-uuid'
_ = require 'underscore'
{File, Project} = require '../../src/models.coffee'

#callback: (files) ->
makeExistingFiles = (projectId, callback) ->
  files = []
  files.push new File {path:'path1', isDir:false, projectId:projectId}
  files.push new File {path:'path2', isDir:false, projectId:projectId}
  files.push new File {path:'path3', isDir:true, projectId:projectId}
  async.forEach files, ((file, cb) ->
    file.save cb
  ), (err) ->
    assert.equal err, null
    callback files

describe 'File', ->
  describe 'insert', ->
    it 'should require isDir', (done) ->
      file = new File {path: 'myPath'}
      file.save (err) ->
        assert.ok err
        assert.equal err.name, 'ValidationError'
        done()

    it 'should require path', (done) ->
      file = new File {isDir: false}
      file.save (err) ->
        assert.ok err
        assert.equal err.name, 'ValidationError'
        done()


  describe 'findByProjectId', ->
    projectId = uuid.v4()
    files = null
    before (done) ->
      makeExistingFiles projectId, (fs) ->
        files = fs
        done()

    it 'finds all the files for a projectId', (done) ->
      File.findByProjectId projectId, (err, returnedFiles) ->
        assert.equal returnedFiles.length, files.length
        done()

  describe 'addFiles with deleteMissing=false', ->
    projectId = uuid.v4()
    existingFiles = null
    addedFiles = null
    newFiles = null
    before (done) ->
      makeExistingFiles projectId, (fs) ->
        existingFiles = fs
        newFiles = []
        newFiles.push path:'path1', isDir:false
        newFiles.push path:'anotherPath1', isDir:true
        File.addFiles newFiles, projectId, (err, files) ->
          assert.equal err, null
          addedFiles = files
          done()

    it 'should return the files correctly', ->
      assert.equal addedFiles.length, newFiles.length

    it 'should not duplicate files', (done) ->
      File.findByProjectId projectId, (err, files) ->
        assert.equal err, null
        assert.equal files.length, 4
        done()

  describe 'addFiles with deleteMissing=true', ->
    projectId = uuid.v4()
    existingFiles = null
    addedFiles = null
    newFiles = null
    before (done) ->
      makeExistingFiles projectId, (fs) ->
        existingFiles = fs
        newFiles = []
        newFiles.push path:'path1', isDir:false
        newFiles.push path:'anotherPath1', isDir:true
        newFiles.push path:'dir1/dir2/dir3/README', isDir:false
        newFiles.push path:'dir1/dir2/dir3/blah', isDir:false

        deleteMissing = true
        File.addFiles newFiles, projectId, deleteMissing, (err, files) ->
          assert.equal err, null
          addedFiles = files
          done()

    it 'should return the files correctly', ->
      assert.equal addedFiles.length, newFiles.length + 3 #dir1, dir2, dir3

    it "should create the parent directories", (done)->
      fileExists = (path)->
      async.forEach ["dir1", "dir1/dir2", "dir1/dir2/dir3"], (path, callback) ->
        File.findOne {path: path}, (err, result)->
          assert result, "no file found for path #{path}"
          assert result.isDir, "#{path} is a directory"
          callback()
      , done

    it 'should not duplicate files', (done) ->
      File.findByProjectId projectId, (err, files) ->
        assert.equal err, null
        assert.equal files.length, newFiles.length + 3 #dir1, dir2, dir3
        paths = _.map newFiles, (file)->file.path
        assert.equal _.uniq(paths).length, paths.length
        done()



