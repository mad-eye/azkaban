routes = (app) ->
  app.get '/init', (req, res)->
    require('./controllers/dementor').init(req, res, app)

module.exports = routes