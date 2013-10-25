_ = require 'underscore'
_path = require 'path'
async = require 'async'
uuid = require 'node-uuid'
{errors, errorType} = require 'madeye-common'
mongoose = require 'mongoose'
Schema = mongoose.Schema

fileSchema = Schema
  _id: {type: String, default: uuid.v4}
  projectId: {type: String, required: true}
  path: {type: String, required: true}
  orderingPath: {type: String, required: true}
  scratch: Boolean
  isDir: {type: Boolean, required: true}
  isLink: {type: Boolean, default: false}
  mtime: {type: Number, default: Date.now}
  modified: {type: Boolean, default: false}
  removed: {type: Boolean, default: false}
  fsChecksum: Number
  loadChecksum: Number
  lastOpened: Number

fileSchema.index ({projectId: 1})
fileSchema.index {projectId: 1, path: 1}, unique: true

fileSchema.statics.findByProjectId = (projectId, options, callback) ->
  if 'function' == typeof options
    callback = options
    options = {}
  selector = {projectId}
  unless options.scratch
    selector['scratch'] = {$ne: true}
  @find selector, callback

File = mongoose.model 'File', fileSchema, 'files'

projectSchema = Schema
  _id: {type: String, default: uuid.v4}
  name: {type: String, required: true}
  closed: {type: Boolean, default: false}
  created: {type: Date, default: Date.now}
  lastOpened: {type: Number, default: Date.now}
  interview: Boolean
  impressJS: Boolean
  hangoutUrl: String
  port: Number
  tunnels: Schema.Types.Mixed
  #files: [fileSchema]

Project = mongoose.model 'Project', projectSchema, 'projects'

activeDirectorySchema = Schema
  projectId: {type:String, required:true}
  path: {type: String, required: true}
  activated: Number
  loaded: Boolean

ActiveDirectory = mongoose.model 'ActiveDirectory', activeDirectorySchema, 'activeDirectories'

projectStatusSchema = Schema
  projectId: {type:String, required:true}
  userId: {type:String, required:true}
  isHangout: Boolean
  connectionId: String
  filePath: String
  heartbeat: Number
  iconId: Number #XXX: This will probably change, and maybe break?

ProjectStatus = mongoose.model 'ProjectStatus', projectStatusSchema, 'projectStatus'

wrapDbError = (err) ->
  return err unless err?
  return err if err.madeye
  errors.new errorType.DATABASE_ERROR, cause:err

exports.File = File
exports.Project = Project
exports.ActiveDirectory = ActiveDirectory
exports.ProjectStatus = ProjectStatus
exports.wrapDbError = wrapDbError
