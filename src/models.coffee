mongoose = require 'mongoose'
{errors, errorType} = require 'madeye-common'

fileSchema = mongoose.Schema
  path: String
  isDir: Boolean

#We don't access files directly?
#exports.File = mongoose.model 'files', fileSchema

projectSchema = mongoose.Schema
  name: String
  closed: {type: Boolean, default: false}
  created: {type: Date, default: Date.now}
  files: [fileSchema]

projectSchema.methods.fileByPath = (path) ->
  for file in @files
    return if file.path == path
  return null

projectSchema.methods.addFiles = (files) ->
  for file in files
    @files.push file unless @fileByPath file.path

Project = mongoose.model 'Project', projectSchema, 'projects'

wrapDbError = (err) ->
  errors.new errorType.DATABASE_ERROR, cause:err

exports.Project = Project
exports.wrapDbError = wrapDbError
