FileController = require('./controllers/fileController')
DementorController = require('./controllers/dementorController')

routes = (app) ->
  fileController = new FileController
  dementorController = new DementorController

  app.post '/project/:projectName', (req, res)->
    dementorController.createProject(req, res)

  app.put '/project/:projectId', (req, res)->
    dementorController.refreshProject(req, res)

  app.get '/project/:projectId/file/:fileId', (req, res)->
    fileController.getFile(req, res)

  app.put '/project/:projectId/file/:fileId', (req, res)->
    fileController.saveFile(req, res)

module.exports = routes
