{Azkaban} = require './src/azkaban'

routes = (app) ->
  azkaban = Azkaban.instance()
  fileController = azkaban.fileController
  dementorController = azkaban.dementorController

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

module.exports = routes
