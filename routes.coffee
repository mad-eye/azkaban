{Azkaban} = require './src/azkaban'
{Settings} = require("madeye-common")
fs = require "fs"
handlebars = require 'handlebars'

routes = (app) ->
  azkaban = Azkaban.instance()
  fileController = azkaban.fileController
  dementorController = azkaban.dementorController
  hangoutController = azkaban.hangoutController
  stripeController = azkaban.stripeController

  app.post '/file-upload/:fileId', (req, res)->

    # for node 0.10: fs.readFile req.files.file.path, {encoding: "utf-8"}, (err,data)->
    fs.readFile req.files.file.path, "utf-8", (err,data)->
      azkaban.bolideClient.setDocumentContents req.params.fileId, data, false, (error)->
        res.json {success :true}

  app.post '/project', (req, res)->
    dementorController.createProject(req, res)

  app.post '/newImpressJSProject', (req, res)->
    fileController.createImpressJSProject(req, res)

  app.put '/project/:projectId', (req, res)->
    dementorController.refreshProject(req, res)

  app.get '/project/:projectId/file/:fileId', (req, res)->
    fileController.getFile(req, res)

  app.put '/project/:projectId/file/:fileId', (req, res)->
    fileController.saveStaticFile(req, res)

  app.get "/", (req, res)->
    res.json {success: true}

  app.get '/hangout/:projectId', (req, res) ->
    hangoutController.gotoHangout(req, res)

  app.put '/hangout/:projectId', (req, res) ->
    hangoutController.registerHangout(req, res)

  app.post '/stripe', (req, res) ->
    stripeController.receiveWebhook req, res

  app.post '/prisonKey', (req, res) ->
    azkaban.prisonController.registerPrisonKey req, res

  app.post '/submitEmail', (req, res) ->
    azkaban.emailController.submitEmail req, res

  installScriptTemplate = handlebars.compile(fs.readFileSync("#{__dirname}/install_madeye.sh.hbs", "utf-8"))
  installScript = installScriptTemplate {
    warehouseUrl: Settings.warehouseUrl
  }
  app.get "/install", (req, res) ->
    res.write installScript
    res.end()

  simpleHangoutTemplate = handlebars.compile(fs.readFileSync("#{__dirname}/simpleHangoutApp.xml.hbs", "utf-8"))
  simpleHangoutXml = simpleHangoutTemplate {apogeeUrl: Settings.apogeeUrl}
  app.get "/simpleHangoutApp.xml", (req, res) ->
    res.write simpleHangoutXml
    res.end()

module.exports = routes
