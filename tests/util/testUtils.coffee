{MongoConnection} = require '../../src/mongoConnection'
{MockDb} = require '../mock/MockMongo'
{DataCenter} = require '../../src/dataCenter'

makeMockDbAndDataCenter = ->
  mockDb = new MockDb
  dataCenter = new DataCenter
  dataCenter.mockDb = mockDb
  dataCenter.getConnection = (errorHandler) ->
    connector = new MongoConnection errorHandler
    connector.Db = this.mockDb
    return connector
  return {dataCenter:dataCenter, mockDb:mockDb}

exports.makeMockDbAndDataCenter = makeMockDbAndDataCenter
