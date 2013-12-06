{Azkaban} = require '../../src/azkaban'
HangoutController = require '../../src/hangoutController'
{assert} = require 'chai'
{MockResponse} = require 'madeye-common'
{Settings} = require 'madeye-common'
{Project, ProjectStatus} = require '../../src/models'
uuid = require 'node-uuid'

describe 'HangoutController', ->
  azkaban = hangoutController = null
  before ->
    Azkaban.initialize()
    azkaban = Azkaban.instance()
    hangoutController = new HangoutController
    azkaban.setService 'hangoutController', hangoutController

  describe 'gotoHangout', ->
    project = null
    beforeEach (done) ->
      project = new Project
        name: "GOTOPROJECT"
      project.save (err, result) ->
        assert.isNull err
        done()

    it "should give new hangout url if project is not registered", (done) ->
      req = {headers: {}, params: {projectId: project._id}}
      res = new MockResponse
      res.redirect = (url) ->
        apogeeUrl = "#{Settings.apogeeUrl}/edit/#{project._id}"
        expectedUrl = Settings.hangoutPrefix + "?gid=" + Settings.hangoutAppId + "&gd=" + apogeeUrl
        assert.equal url, expectedUrl
        done()

      hangoutController.gotoHangout req, res

    it "should give existing hangout url if project has one", (done) ->
      req = {headers: {}, params: {projectId: project._id}}
      existingHangoutUrl = "http://hangout.google.com/_/TEST#{uuid.v4()}"
      res = new MockResponse
      res.redirect = (url) ->
        expectedUrl = existingHangoutUrl + "?gid=" + Settings.hangoutAppId
        assert.equal url, expectedUrl
        done()

      Project.update {_id:project._id}, {hangoutUrl:existingHangoutUrl}, (err, count) ->
        assert.isNull err
        hangoutController.gotoHangout req, res

