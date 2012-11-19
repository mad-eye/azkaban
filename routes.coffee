routes = (app) ->
  app.post '/init', (req, res)->
    require('./controllers/dementor').init(req, res, app)

  app.get '/project/:projectId/file/:fileId', (req, res) ->
    require('./controllers/fileController').getFile(req, res)

  app.put '/project/:projectId/file/:fileId', (req, res) ->
    require('./controllers/fileController').saveFile(req, res)

module.exports = routes
