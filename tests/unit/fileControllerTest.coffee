assert = require("chai").assert
fs = require "fs"
uuid = require 'node-uuid'
sinon = require 'sinon'
{Azkaban} = require '../../src/azkaban'
FileSyncer = require '../../src/fileSyncer'
FileController = require '../../src/fileController'
{MockResponse} = require 'madeye-common'
{Project, File} = require '../../src/models'
{crc32} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
_ = require "underscore"

describe 'fileController', ->
  Azkaban.initialize()
  azkaban = Azkaban.instance()
  azkaban.setService 'fileSyncer', new FileSyncer
  fileController = undefined

  describe 'createImpressJSProject', ->
    #TODO should put this into a callback..

    projectId = undefined
    tmpWorkDirectory = "/tmp/fileControllerTestWorkspace_#{uuid.v4()}"

    controller = new FileController {userStaticFiles: tmpWorkDirectory}

    azkaban = Azkaban.instance()
    azkaban.setService "fileController", controller
    mockBolide =
      setDocumentContents: (docId, contents, reset=false, callback) ->
        hitBolideClient = true
        callback null

    azkaban.setService "bolideClient", mockBolide

    it "returns the projectId", (done)->
      fakeResponse = new MockResponse
      fakeResponse.onEnd = (body)->
        message = JSON.parse body
        projectId = message.projectId
        assert.ok projectId
        done()

      controller.createImpressJSProject({}, fakeResponse)

    it 'should create a project on the filesystem', (done)->
      fs.stat "#{tmpWorkDirectory}/#{projectId}", (err, stats)->
        assert.isNull err
        fs.stat "#{tmpWorkDirectory}/#{projectId}/index.html", (err, stats)->
          assert.isNull err
          done()

    it 'should create projects and files in the db', (done)->
      project = Project.findOne {_id: projectId}, (err, doc)->
        assert.ok doc
        files = File.find {projectId}, (err, docs)->
          expectedPath = "index.html"
          indexDoc = _.find docs, (doc)->
            doc.path == expectedPath
          assert.ok indexDoc, "expected to find path #{expectedPath}"
          done()

    it "should ensure the files are created in bolide"

  describe "saveStaticFile", ->
    projectId = uuid.v4()
    tmpWorkDirectory = "/tmp/fileControllerTestWorkspace_#{projectId}"
    projectDirectory = "/tmp/fileControllerTestWorkspace_#{projectId}/#{projectId}"

    fs.mkdirSync tmpWorkDirectory
    fs.mkdirSync projectDirectory
    controller = new FileController {userStaticFiles: tmpWorkDirectory}

    it "should write contents to disk on save", (done)->
      controller.saveStaticFile

      azkaban.setService "fileController", controller

      novelContents = "a tale"

      fakeResponse = new MockResponse
      fakeResponse.onEnd = (body)->
        message = JSON.parse body
        #console.log "MESSAGE", message
        contents = fs.readFileSync "#{projectDirectory}/novel.txt", "utf-8"
        assert.equal contents, novelContents
        done()

      file = new File {path: "novel.txt", isDir: false, orderingPath: "novel.txt", projectId}
      file.save (err)->
        console.error err if err
        controller.saveStaticFile {params: {fileId: file._id}, body: {contents: novelContents}}, fakeResponse
