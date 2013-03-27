{assert} = require 'chai'
async = require 'async'
uuid = require 'node-uuid'
_ = require 'underscore'
{File, Project} = require '../../src/models.coffee'
FileSyncer = require '../../src/fileSyncer'

#callback: (files) ->
makeExistingFiles = (projectId, callback) ->
  files = []
  files.push new File {path:'path1', isDir:false, projectId:projectId}
  files.push new File {path:'path2', isDir:false, projectId:projectId}
  files.push new File {path:'path3', isDir:true, projectId:projectId}
  async.each files, ((file, cb) ->
    file.save cb
  ), (err) ->
    assert.equal err, null
    callback files


describe 'FileSyncer', ->
  fileSyncer = new FileSyncer()

  describe 'syncFiles with deleteMissing=false', ->
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
        fileSyncer.syncFiles newFiles, projectId, (err, files) ->
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

  describe 'syncFiles with deleteMissing=true', ->
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
        fileSyncer.syncFiles newFiles, projectId, deleteMissing, (err, files) ->
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

  describe 'syncFiles with mtime', ->
    projectId = uuid.v4()
    fileId = otherFileId = null
    savedFile = otherSavedFile = unopenedSavedFile = null
    now = Date.now()
    ago = now - 60*1000
    before (done) ->
      path = "a/path.txt"
      otherPath = "a/anotherpath.txt"
      unopenedPath = "a/unopened.txt"
      existingFile = new File {path, projectId, isDir:false, mtime:ago, lastOpened:new Date()}
      fileId = existingFile._id
      otherExistingFile = new File {path:otherPath, projectId, isDir:false, mtime:ago, lastOpened:new Date()}
      otherFileId = otherExistingFile._id
      unopenedFile = new File {path:unopenedPath, projectId, isDir:false, mtime:ago}
      unopenedFileId = unopenedFile._id
      async.parallel [(cb) ->
        existingFile.save cb
      , (cb) ->
        otherExistingFile.save cb
      , (cb) ->
        unopenedFile.save cb
      ], (err, savedFiles) ->
        assert.isNull err, "Found error #{err}"
        newFile = {path, isDir:false, mtime: now}
        otherNewFile = {path:otherPath, isDir:false, mtime: ago}
        unopenedNewFile = {path:unopenedPath, isDir:false, mtime: now}
        deleteMissing = false
        fileSyncer.syncFiles [newFile, otherNewFile], projectId, deleteMissing, (err, files) ->
          assert.isNull err
          async.parallel [(cb) ->
            File.findById fileId, (err, file) ->
              savedFile = file
              cb err
          , (cb) ->
            File.findById otherFileId, (err, file) ->
              otherSavedFile = file
              cb err
          , (cb) ->
            File.findById unopenedFileId, (err, file) ->
              unopenedSavedFile = file
              cb err
          ], (err) ->
            assert.isNull err
            done()

    it 'should update mtime only on new file', ->
      assert.equal savedFile.mtime, now
      assert.equal otherSavedFile.mtime, ago
      assert.equal savedFile.mtime, now

    it 'should set modified=true only on the new file', ->
      assert.isTrue savedFile.modified
      assert.isFalse otherSavedFile.modified
      assert.isFalse unopenedSavedFile.modified

    it 'should set modified_locally=true only on the new file', ->
      assert.isTrue savedFile.modified_locally
      assert.isFalse otherSavedFile.modified_locally
      assert.isFalse unopenedSavedFile.modified_locally

