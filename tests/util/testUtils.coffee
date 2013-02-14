assert = require 'assert'

exports.assertFilesCorrect = (files, targetFiles, projectId) ->
  # not true when parent directories are added as well
  # assert.equal files.length, targetFiles.length, "Number of files incorrect."
  targetMap = {}
  targetMap[file.path] = file for file in targetFiles
  for file in files
    assert.ok file._id
    assert.equal file.projectId, projectId if projectId
    targetFile = targetMap[file.path]
    assert.ok targetFile
    assert.equal file.isDir, targetFile.isDir

