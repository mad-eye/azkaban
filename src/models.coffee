mongoose = require 'mongoose'
async = require 'async'
uuid = require 'node-uuid'
{errors, errorType} = require 'madeye-common'

fileSchema = mongoose.Schema
  _id: {type: String, default: uuid.v4}
  projectId: {type: String, required: true}
  path: {type: String, required: true}
  isDir: {type: Boolean, required: true}
  modified: {type: Boolean, default: false}

fileSchema.statics.findByProjectId = (projectId, callback) ->
  @find {projectId: projectId}, callback

fileSchema.statics.addFiles = (files, projectId, deleteMissing=false, callback) ->
  if 'function' == typeof deleteMissing
    callback = deleteMissing
    deleteMissing = false

  files = files[..] #Prevent files mutation
  newFileMap = {}
  newFileMap[file.path] = file for file in files

  #add any parent directories that are missing
  parentsMap = {}
  for file in files
    path = file.path
    while path.lastIndexOf('/') > -1
      path = path.substr 0, path.lastIndexOf('/')
      if (path of parentsMap) or (path of newFileMap)
        break
      else
        parentsMap[path] = {path: path, projectId: @projectId, isDir: true}

  for path, parent of parentsMap
    files.push parent unless newFileMap[path]

  @findByProjectId projectId, (err, existingFiles) ->
    if err then callback wrapDbError err; return

    filesToReturn = []
    filesToSave = []
    existingFileMap = {}
    existingFileMap[file.path] = file for file in existingFiles
    for file in files
      if file.path of existingFileMap
        #FIXME: we should extend existingFile with file, for when we add fields
        filesToReturn.push existingFileMap[file.path]
        delete existingFileMap[file.path]
      else
        file.projectId = projectId
        newFile = new File file
        filesToSave.push newFile

    #Specifying 'File' is a little dangerous, but @ returns a Promise, not a true Model object.
    File.create filesToSave, (err) ->
      if err then callback wrapDbError err; return
      savedFiles = Array.prototype.slice.call arguments, 1
      filesToReturn = filesToReturn.concat savedFiles
      unless deleteMissing
        callback null, filesToReturn
      else
        filesToDelete = []
        filesToDelete.push file for path, file of existingFileMap
        async.each filesToDelete, ((file, cb) ->
          file.remove cb
        ), (err) ->
          if err then callback wrapDbError err; return
          callback null, filesToReturn



File = mongoose.model 'File', fileSchema, 'files'

projectSchema = mongoose.Schema
  _id: {type: String, default: uuid.v4}
  name: {type: String, required: true}
  closed: {type: Boolean, default: false}
  created: {type: Date, default: Date.now}
  #files: [fileSchema]

Project = mongoose.model 'Project', projectSchema, 'projects'

wrapDbError = (err) ->
  return err if err.madeye
  errors.new errorType.DATABASE_ERROR, cause:err

exports.File = File
exports.Project = Project
exports.wrapDbError = wrapDbError
