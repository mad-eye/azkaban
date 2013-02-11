mongoose = require 'mongoose'
async = require 'async'
uuid = require 'node-uuid'
{errors, errorType} = require 'madeye-common'
_ = require 'underscore'

fileSchema = mongoose.Schema
  _id: {type: String, default: uuid.v4}
  projectId: {type: String, required: true}
  path: {type: String, required: true}
  isDir: {type: Boolean, required: true}

#file objects for all the parents
fileSchema.virtual("parents").get ->
  parents = []
  path = undefined
  parents = @path.split("/")[0..-2].map (dir)->
    if path
      path = "#{path}/#{dir}"
    else
      path = dir
  return parents.map (path)->
    new File {path: path, projectId: @projectId, isDir: true}

fileSchema.statics.findByProjectId = (projectId, callback) ->
  @find {projectId: projectId}, callback

fileSchema.statics.addFiles = (files, projectId, deleteMissing=false, callback) ->
  if 'function' == typeof deleteMissing
    callback = deleteMissing
    deleteMissing = false

  files = _.map files, (file)->
    new File {path: file.path, isDir: file.isDir}

  newFileMap = {}
  _.each files, (file) ->
    newFileMap[file.path] = file

  #add any parent directories that are missing
  parentsMap = {}
  for file in files
    for parent in file.parents
      parentsMap[parent.path] = parent

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
        filesToReturn.push existingFileMap[file.path]
        delete existingFileMap[file.path]
      else
        file.projectId = projectId
        newFile = new File file
        filesToSave.push newFile

    #This is a little dangerous, but @ returns a Promise, not a true Model object.
    File.create filesToSave, (err) ->
      if err then callback wrapDbError err; return
      savedFiles = Array.prototype.slice.call arguments, 1
      filesToReturn = filesToReturn.concat savedFiles
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
