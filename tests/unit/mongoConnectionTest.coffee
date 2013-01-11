{MongoConnection} = require '../../src/mongoConnection'
{ServiceKeeper} = require '../../ServiceKeeper'
{Settings} = require 'madeye-common'
{MockDb} = require '../mock/MockMongo'
assert = require 'assert'

runTests = ->
  it 'should open', (done) ->
    db = new MongoConnection (err) ->
      assert.equal err, null
    db.connect ->
      assert.ok db.db
      db.close()
      done()

  it 'should be able to write and read entries', (done) ->
    db = new MongoConnection (err) ->
      assert.equal err, null
    db.connect ->
      db.remove {}, 'test', ->
        db.insert [{name:'fred'}, {name:'joe'}], 'test', (docs) ->
          people = {}
          assert.equal docs.length, 2
          for doc in docs
            assert.ok doc._id
            people[doc._id] = doc
            fredFound = true if doc.name == 'fred'
            joeFound = true if doc.name == 'joe'
          assert.ok fredFound
          assert.ok joeFound

          db.findAll {}, 'test', (docs) ->
            assert.equal docs.length, 2
            for doc in docs
              person = people[doc._id]
              assert.deepEqual doc, person

            db.close()
            done()


describe 'MongoConnection', ->
  describe 'using the real db', ->
    before ->
      ServiceKeeper.reset()
      Settings.mockDb = false

    runTests()

  describe 'using the MockDb', ->
    before ->
      ServiceKeeper.reset()
      Settings.mockDb = true

    it 'should set the methods on serviceKeeper', ->
      serviceKeeper = ServiceKeeper.instance()
      assert.ok serviceKeeper.makeDbConnection
      mockDb = serviceKeeper.makeDbConnection()
      assert.ok mockDb.isMock()

    it 'should be using the mockDb', ->
      db = new MongoConnection (err) ->
        assert.equal err, null
      assert.ok db.Db.isMock()

    runTests()
