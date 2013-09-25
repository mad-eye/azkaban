{assert} = require 'chai'
async = require 'async'
uuid = require 'node-uuid'
_ = require 'underscore'
{File, Project} = require '../../src/models'
FileSyncer = require '../../src/fileSyncer'
{assertFilesCorrect} = require '../util/testUtils'

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
    addedFiles = null
    newFiles = null
    scratchFile = null
    before (done) ->
      makeExistingFiles projectId, (fs) ->
        fileSyncer.addScratchFile projectId, (err, doc) ->
          assert.ok !err?
          scratchFile = doc
          newFiles = []
          newFiles.push addOrderingPath path:'path1', isDir:false
          newFiles.push addOrderingPath path:'anotherPath1', isDir:true

          deleteMissing = true
          fileSyncer.syncFiles newFiles, projectId, deleteMissing, (err, files) ->
            assert.isNull err
            addedFiles = files
            done()

    it 'should not duplicate files', (done) ->
      File.findByProjectId projectId, (err, files) ->
        assert.isNull err
        assertFilesCorrect files, newFiles
        done()

    it 'should not delete the scratch file', (done) ->
      File.findById scratchFile._id, (err, doc) ->
        assert.isNull err
        assert.ok doc
        assertFilesCorrect [doc], [scratchFile]
        done()

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

  describe 'addScratchFile', ->
    projectId = uuid.v4()
    
    it 'should make a scratch file', (done) ->
      fileSyncer.addScratchFile projectId, (err, scratchFile) ->
        assert.isNotNull scratchFile
        assert.isNull err
        assert.isTrue scratchFile.scratch, "scratch should be set"
        assert.ok scratchFile._id
        assert.ok scratchFile.path
        assert.ok scratchFile.orderingPath
        assert.isFalse scratchFile.isDir
        File.findOne {projectId: projectId, scratch:true}, (err, dbFile) ->
          assert.isNotNull dbFile
          assert.equal dbFile._id, scratchFile.id
          done()
