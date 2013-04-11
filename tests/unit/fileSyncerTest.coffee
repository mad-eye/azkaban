{assert} = require 'chai'
async = require 'async'
uuid = require 'node-uuid'
_ = require 'underscore'
{File, Project} = require '../../src/models.coffee'
FileSyncer = require '../../src/fileSyncer'

#callback: (files) ->
makeExistingFiles = (projectId, callback) ->
  files = []
  files.push new File {path:'path1', orderingPath:'path1', isDir:false, projectId:projectId}
  files.push new File {path:'path2', orderingPath:'path2', isDir:false, projectId:projectId}
  files.push new File {path:'path3', orderingPath:'path3', isDir:true, projectId:projectId}
  async.each files, ((file, cb) ->
    file.save cb
  ), (err) ->
    assert.equal err, null
    callback files

addOrderingPath = (files) ->
  array = true
  unless Array.isArray files
    array = false
    files = [files]
  for file in files
    file.orderingPath = file.path.replace(/\ /g, "!").replace(/\//g, " ").toLowerCase()
  if array then return files else return files[0]


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
        newFiles.push addOrderingPath path:'path1', isDir:false
        newFiles.push addOrderingPath path:'anotherPath1', isDir:true
        newFiles.push addOrderingPath path:'dir1/dir2/dir3/README', isDir:false
        newFiles.push addOrderingPath path:'dir1/dir2/dir3/blah', isDir:false

        deleteMissing = true
        fileSyncer.syncFiles newFiles, projectId, deleteMissing, (err, files) ->
          assert.isNull err
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
      existingFile = new File addOrderingPath {path, projectId, isDir:false, mtime:ago, modified:true, lastOpened: Date.now()}
      fileId = existingFile._id
      otherExistingFile = new File addOrderingPath {path:otherPath, projectId, isDir:false, mtime:ago, lastOpened: Date.now()}
      otherFileId = otherExistingFile._id
      unopenedFile = new File addOrderingPath {path:unopenedPath, projectId, isDir:false, mtime:ago}
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

    it 'should set modified_locally=true only on the new file', ->
      assert.isTrue savedFile.modified_locally
      assert.isFalse otherSavedFile.modified_locally
      assert.isFalse unopenedSavedFile.modified_locally

  describe 'completeParentFiles', ->
    projectId = uuid.v4()
    it 'should leave complete files alone', ->
      files = [
        {path: 'dir1', isDir:true, projectId},
        {path: 'dir1/dir2', isDir:true, projectId},
        {path: 'dir1/dir2/file.txt', isDir:true, projectId},
      ]
      addOrderingPath files
      oldFiles = files[..]
      fileSyncer.completeParentFiles files
      assert.deepEqual files, oldFiles

    it 'should complete a file missing all parents', ->
      files = [
        {path: 'dir1/dir2/file.txt', isDir:false, projectId},
      ]
      addOrderingPath files
      completeFiles = files[..]
      completeFiles.push addOrderingPath {path: 'dir1/dir2', isDir:true, projectId}
      completeFiles.push addOrderingPath {path: 'dir1', isDir:true, projectId}
      _.sortBy completeFiles, 'path'
      fileSyncer.completeParentFiles files
      _.sortBy files, 'path'
      assert.deepEqual files, completeFiles
      assert.ok file.projectId for file in files

    it 'should complete a file missing only top parent', ->
      files = [
        {path: 'dir1/dir2/file.txt', isDir:false, projectId},
        {path: 'dir1/dir2', isDir:true, projectId}
      ]
      addOrderingPath files
      completeFiles = files[..]
      completeFiles.push addOrderingPath {path: 'dir1', isDir:true, projectId}
      _.sortBy completeFiles, 'path'
      fileSyncer.completeParentFiles files
      _.sortBy files, 'path'
      assert.deepEqual files, completeFiles
      assert.ok file.projectId for file in files

    it 'should not duplicate missing parents', ->
      files = [
        {path: 'dir1/file1.txt', isDir:false, projectId},
        {path: 'dir1/file2.txt', isDir:false, projectId},
      ]
      addOrderingPath files
      completeFiles = files[..]
      completeFiles.push addOrderingPath {path: 'dir1', isDir:true, projectId}
      _.sortBy completeFiles, 'path'
      fileSyncer.completeParentFiles files
      _.sortBy files, 'path'
      assert.deepEqual files, completeFiles
      assert.ok file.projectId for file in files

  describe 'partitionFiles', ->
    newFiles = unmodifiedFiles = modifiedFiles = orphanedFiles = null
    existingFiles = null
    projectId = uuid.v4()
    now = Date.now()
    ago = now - 20*60*1000

    before ->
      files = [
          {path: 'dir1', isDir:true, mtime:ago, projectId},
          {path: 'dir1/file1.txt', isDir:true, mtime: now, projectId},
          {path: 'dir1/file2.txt', isDir:true, mtime: ago, projectId},
          {path: 'file3.txt', isDir:true, mtime: now, projectId},
          {path: 'file4.txt', isDir:true, mtime: ago, projectId},
      ]
      existingFiles = [
          {path: 'dir1', _id:uuid.v4(), isDir:true, mtime:ago, projectId},
          {path: 'dir1/file1.txt', _id:uuid.v4(), isDir:true, mtime: ago, projectId},
          {path: 'dir1/file2.txt', _id:uuid.v4(), isDir:true, mtime: ago, projectId},
          {path: 'dir2/file1.txt', _id:uuid.v4(), isDir:false, mtime: ago, projectId},
          {path: 'file3.txt', _id:uuid.v4(), isDir:true, lastOpened: Date.now(), mtime: ago, projectId},
      ]
      [newFiles, unmodifiedFiles, modifiedFiles, orphanedFiles] = fileSyncer.partitionFiles files, existingFiles

    it 'should have the right newFiles', ->
      newFiles = _.sortBy newFiles, 'path'
      assert.deepEqual newFiles, [{path: 'file4.txt', isDir:true, mtime: ago, projectId}]

    it 'should have the right unmodifiedFiles', ->
      unmodifiedFiles = _.sortBy unmodifiedFiles, 'path'
      f1 = _.find existingFiles, (f) -> f.path == 'dir1'
      f2 = _.find existingFiles, (f) -> f.path == 'dir1/file2.txt'
      assert.deepEqual unmodifiedFiles, [f1, f2]

    it 'should have the right modifiedFiles', ->
      modifiedFiles = _.sortBy modifiedFiles, 'path'
      f1 = _.find existingFiles, (f) -> f.path == 'dir1/file1.txt'
      f2 = _.find existingFiles, (f) -> f.path == 'file3.txt'
      f1.mtime = f2.mtime = now
      assert.deepEqual modifiedFiles, [f1, f2]

    it 'should have the right orphanedFiles', ->
      orphanedFiles = _.sortBy orphanedFiles, 'path'
      f1 = _.find existingFiles, (f) -> f.path == 'dir2/file1.txt'
      assert.deepEqual orphanedFiles, [f1]

  describe 'updateModifiedFiles', ->
    projectId = uuid.v4()
    modifiedFiles = [
      {path:'file1.txt', isDir: false, projectId}
      {path:'file2.txt', isDir: false, lastOpened: Date.now(), projectId}
      {path:'file3.txt', isDir: false, lastOpened: Date.now(), modified:true, projectId}
    ]
    addOrderingPath modifiedFiles
    before (done) ->
      File.create modifiedFiles, (err) ->
        assert.isNull err
        modifiedFiles = Array.prototype.slice.call arguments, 1
        fileSyncer.updateModifiedFiles modifiedFiles, done

    it 'should set modified_locally correctly', (done) ->
      File.findByProjectId projectId, (err, files) ->
        fileMap = {}
        fileMap[file.path] = file for file in files
        assert.ok !fileMap['file1.txt'].modified_locally
        assert.isTrue fileMap['file2.txt'].modified_locally
        assert.isTrue fileMap['file3.txt'].modified_locally
        done()

