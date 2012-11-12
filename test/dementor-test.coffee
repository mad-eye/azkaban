assert = require 'assert'
request = require 'request'
app = require '../app'
console.log "Found app", app

describe "dementor", ->
  describe "init", ->
    body = response = null
    before (done) ->
      options =
        uri: "http://localhost:#{app.get('port')}/init"
      request options, (err, _res, _body) ->
        body = _body
        response = _res
        done()
    it "returns a 200", ->
      assert.ok response.statusCode == 200

