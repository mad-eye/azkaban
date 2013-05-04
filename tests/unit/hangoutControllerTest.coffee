{Azkaban} = require '../../src/azkaban'
HangoutController = require '../../src/hangoutController'
{assert} = require 'chai'
{MockResponse} = require 'madeye-common'
{Project} = require '../../src/models'
uuid = require 'node-uuid'

describe 'HangoutController fweep', ->
  Azkaban.initialize()
  azkaban = Azkaban.instance()
  hangoutController = new HangoutController
  azkaban.setService 'hangoutController', hangoutController

  it "should allow registration of a hangout url", (done)->
    hangoutTestId = "HANGOUT_TEST_ID"
    project = new Project
      name: "FAKE PROJECT"
    project.save()
    req = {params: {hangoutId: hangoutTestId}, body: {projectId: project._id}}
    res = new MockResponse
    res.onEnd = (_body) ->
      Project.findOne {_id: project._id}, (err,result)->
        assert.equal result.hangoutId, hangoutTestId
        done()
    hangoutController.registerHangout req, res
