_ = require 'underscore'
_path = require 'path'
mongoose = require 'mongoose'
async = require 'async'
uuid = require 'node-uuid'
{errors, errorType} = require 'madeye-common'
{logger} = require './logger'

fileSchema = mongoose.Schema
  _id: {type: String, default: uuid.v4}
  projectId: {type: String, required: true}
  path: {type: String, required: true}
  isDir: {type: Boolean, required: true}
  isLink: {type: Boolean, default: false}
  mtime: {type: Number, default: Date.now}
  modified: {type: Boolean, default: false}
  removed: {type: Boolean, default: false}
  modified_locally: {type: Boolean, default: false}
  checksum: Number
  lastOpened: Number

fileSchema.statics.findByProjectId = (projectId, callback) ->
  @find {projectId: projectId}, callback



File = mongoose.model 'File', fileSchema, 'files'

projectSchema = mongoose.Schema
  _id: {type: String, default: uuid.v4}
  name: {type: String, required: true}
  closed: {type: Boolean, default: false}
  created: {type: Date, default: Date.now}
  #files: [fileSchema]

Project = mongoose.model 'Project', projectSchema, 'projects'

wrapDbError = (err) ->
  return err unless err?
  return err if err.madeye
  errors.new errorType.DATABASE_ERROR, cause:err

exports.File = File
exports.Project = Project
exports.wrapDbError = wrapDbError
