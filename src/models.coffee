_ = require 'underscore'
_path = require 'path'
async = require 'async'
uuid = require 'node-uuid'
{errors} = require 'madeye-common'
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

fileSchema.index {projectId: 1}
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

workspaceSchema = Schema
  userId: {type:String, required:true}

workspaceSchema.index {userId: 1}, unique: true
Workspaces = mongoose.model 'Workspace', workspaceSchema, 'workspaces'

wrapDbError = (err) ->
  #did this ever work? it seems like error types are never exported?

  # return err unless err?
  # return err if err.madeye
  # console.log "CAUSE", err
  # errors.new DATABASE_ERROR, cause:err/
  throw err

newsletterEmailSchema = Schema
  email: String
  added: {type: Date, default: Date.now}

NewsletterEmail = mongoose.model 'NewsletterEmail', newsletterEmailSchema, 'newsletterEmails'

stripeEventSchema = Schema
  id: {type:String, required:true}
  created: {type:Number, required:true}
  livemode: {type:Boolean, required:true}
  type: {type:String, required:true}
  data: Schema.Types.Mixed
  object: {type:String, required:true}
  pending_webhooks: Number
  request: {type:String, required:true}

StripeEvent = mongoose.model 'StripeEvent', stripeEventSchema, 'stripeEvents'

exports.File = File
exports.Project = Project
exports.StripeEvent = StripeEvent
exports.NewsletterEmail = NewsletterEmail
exports.wrapDbError = wrapDbError
