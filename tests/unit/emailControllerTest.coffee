assert = require("chai").assert
EmailController = require '../../src/emailController'
{NewsletterEmail} = require '../../src/models'
{MockResponse} = require 'madeye-common'

describe 'EmailController', ->
  emailController = new EmailController

  describe 'submitEmail', ->
    it 'should save an email', (done) ->
      email = 'joe@azccf.edu'
      fakeResponse = new MockResponse
      fakeResponse.onEnd = (body)->
        message = JSON.parse body
        assert.equal email, message.email
        NewsletterEmail.findOne {email}, (err, doc) ->
          assert.isNull err
          assert.equal doc.email, email
          done()

      emailController.submitEmail({body:{email}}, fakeResponse)


