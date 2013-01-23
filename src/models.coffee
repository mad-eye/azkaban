mongoose = require 'mongoose'

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

exports.Project = mongoose.model 'Project', projectSchema, 'projects'
