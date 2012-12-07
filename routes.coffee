FileController = require('./controllers/fileController')

routes = (app) ->
  fileController = new FileController
  app.post '/init', (req, res)->
    require('./controllers/dementorController').init(req, res, app)

  app.get '/project/:projectId/file/:fileId', (req, res)->
    fileController.getFile(req, res)

  app.post '/project/:projectId/file/:fileId', (req, res)->
    fileController.saveFile(req, res)

module.exports = routes
