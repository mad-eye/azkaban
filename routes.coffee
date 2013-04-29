{Azkaban} = require './src/azkaban'
fs = require "fs"

routes = (app) ->
  azkaban = Azkaban.instance()
  fileController = azkaban.fileController
  dementorController = azkaban.dementorController

  app.post '/file-upload/:fileId', (req, res)->
    fs.readFile req.files.file.path, {encoding: "utf-8"}, (err,data)->
      azkaban.bolideClient.setDocumentContents req.params.fileId, data, false, (error)->
        res.json {success :true}

  app.post '/project', (req, res)->
    dementorController.createProject(req, res)

  app.put '/project/:projectId', (req, res)->
    dementorController.refreshProject(req, res)

  app.get '/project/:projectId/file/:fileId', (req, res)->
    fileController.getFile(req, res)

  app.put '/project/:projectId/file/:fileId', (req, res)->
    fileController.saveFile(req, res)

  app.get "/", (req, res)->
    res.json {success: true}

  app.put '/hangout/:hangoutId', (req, res) ->
    hangoutController.registerHangout(req, res)

module.exports = routes
