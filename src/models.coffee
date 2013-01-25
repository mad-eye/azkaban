mongoose = require 'mongoose'
async = require 'async'
uuid = require 'node-uuid'
{errors, errorType} = require 'madeye-common'

fileSchema = mongoose.Schema
  _id: {type: String, default: uuid.v4}
  projectId: {type: String, required: true}
  path: {type: String, required: true}
  isDir: {type: Boolean, required: true}

fileSchema.statics.findByProjectId = (projectId, callback) ->
  @find {projectId: projectId}, callback

fileSchema.statics.addFiles = (files, projectId, deleteMissing=false, callback) ->
  if 'function' == typeof deleteMissing
    callback = deleteMissing
    deleteMissing = false
  @findByProjectId projectId, (err, existingFiles) ->
    if err then callback wrapDbError err; return

    filesToReturn = []
    filesToSave = []
    existingFileMap = {}
    existingFileMap[file.path] = file for file in existingFiles
    for file in files
      if file.path of existingFileMap
        filesToReturn.push existingFileMap[file.path]
        delete existingFileMap[file.path]
      else
        file.projectId = projectId
        newFile = new File file
        filesToSave.push newFile
        filesToReturn.push newFile

    async.forEach filesToSave, ((file, cb) ->
      file.save cb
    ), (err) ->
      if err then callback wrapDbError err; return
      unless deleteMissing
        callback null, filesToReturn
      else
        filesToDelete = []
        filesToDelete.push file for path, file of existingFileMap
        async.forEach filesToDelete, ((file, cb) ->
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
  return err if errorType.DATABASE_ERROR == err.type
  errors.new errorType.DATABASE_ERROR, cause:err

exports.File = File
exports.Project = Project
exports.wrapDbError = wrapDbError
