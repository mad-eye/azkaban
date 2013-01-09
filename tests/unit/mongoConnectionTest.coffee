{MongoConnection} = require '../../src/mongoConnection'
assert = require 'assert'

describe 'MongoConnection', ->
  it 'should open', (done) ->
    db = MongoConnection.instance (err) ->
      assert.equal err, null
    db.connect ->
      assert.ok db.db
      db.close()
      done()



