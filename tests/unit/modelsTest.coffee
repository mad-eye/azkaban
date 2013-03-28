{assert} = require 'chai'
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
  async.each files, ((file, cb) ->
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

