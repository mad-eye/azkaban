{Azkaban} = require '../../src/azkaban'
HangoutController = require '../../src/hangoutController'
{assert} = require 'chai'
{MockResponse} = require 'madeye-common'
{Settings} = require 'madeye-common'
{Project} = require '../../src/models'
uuid = require 'node-uuid'

describe 'HangoutController', ->
  azkaban = hangoutController = null
  before ->
    Azkaban.initialize()
    azkaban = Azkaban.instance()
    hangoutController = new HangoutController
    azkaban.setService 'hangoutController', hangoutController

  describe 'registerHangout', ->
    project = null
    before (done) ->
      project = new Project
        name: "FAKE PROJECT"
      project.save (err, result) ->
        assert.isNull err
        done()

    it "should allow registration of a hangout url", (done)->
      hangoutTestUrl = "http://hangout.google.com/_/TEST#{uuid.v4()}"
      req = {body: {hangoutUrl: hangoutTestUrl}, params: {projectId: project._id}}
      res = new MockResponse
      res.onEnd = (_body) ->
        Project.findOne {_id: project._id}, (err,result)->
          assert.isNull err
          console.log "Found result", result
          assert.equal result.hangoutUrl, hangoutTestUrl
          done()
      hangoutController.registerHangout req, res

  describe 'gotoHangout', ->
    project = null
    before (done) ->
      project = new Project
        name: "GOTOPROJECT"
      project.save (err, result) ->
        assert.isNull err
        done()

    it "should give new hangout url if project is not registered", (done) ->
      req = {params: {projectId: project._id}}
      res = new MockResponse
      res.redirect = (url) ->
        apogeeUrl = "#{Settings.apogeeUrl}/edit/#{project._id}"
        expectedUrl = Settings.hangoutPrefix + "?gid=" + Settings.hangoutAppId + "&gd=" + apogeeUrl
        assert.equal url, expectedUrl
        done()

      hangoutController.gotoHangout req, res

    it "should give existing hangout url if project is registered", (done) ->
      req = {params: {projectId: project._id}}
      existingHangoutUrl = "http://hangout.google.com/_/TEST#{uuid.v4()}"
      res = new MockResponse
      res.redirect = (url) ->
        expectedUrl = existingHangoutUrl + "?gid=" + Settings.hangoutAppId
        assert.equal url, expectedUrl
        done()

      Project.update {_id:project._id}, {hangoutUrl:existingHangoutUrl}, (err, count) ->
        assert.isNull err
        hangoutController.gotoHangout req, res

