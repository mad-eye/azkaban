assert = require 'assert'
request = require 'request'
url = require 'url'
app = require '../../app'
{ServiceKeeper} = require '../../ServiceKeeper'
{MongoConnector} = require '../../connectors/MongoConnector'
{MockDb} = require '../mock/MockMongo'

describe "controllers/dementor", ->
  describe "init", ->
    body = bodyStr = response = null
    before (done) ->
      mockDb = new MockDb()
      mongoConnector = new MongoConnector(mockDb)
      ##Uncomment to put in a broken mock mongo instance.
      #ServiceKeeper.mongoConnector = mongoConnector
      options =
        uri: "http://localhost:#{app.get('port')}/init"
      request options, (err, _res, _body) ->
        console.log "Found body ", _body
        bodyStr = _body
        try
          body = JSON.parse _body
        catch error
          "Let the test catch this."
        response = _res
        done()
    it "returns a 200", ->
      assert.ok response.statusCode == 200
    it "returns valid JSON", ->
      assert.doesNotThrow ->
        JSON.parse(bodyStr)
    it "returns a url", ->
      assert.ok body.url, "Body #{bodyStr} doesn't have url property."
    it "returns a url with the correct hostname", ->
      console.log "Found url:", body.url
      u = url.parse(body.url)
      assert.ok u.hostname
      assert.equal u.hostname, app.get('apogee.hostname')
