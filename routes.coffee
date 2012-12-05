FileController = require('./controllers/fileController')

routes = (app) ->
  fileController = new FileController
  app.post '/init', (req, res)->
    require('./controllers/dementor').init(req, res, app)

  app.get '/project/:projectId/file/:fileId', (req, res)->
    fileController.getFile(req, res)

  app.put '/project/:projectId/file/:fileId', (req, res)->
    fileController.saveFile(req, res)

module.exports = routes
