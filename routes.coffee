routes = (app) ->
  app.post '/init', (req, res)->
    require('./controllers/dementor').init(req, res, app)

module.exports = routes