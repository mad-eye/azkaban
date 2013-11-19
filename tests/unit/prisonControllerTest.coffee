_ = require 'underscore'
hat = require 'hat'
{assert} = require 'chai'
PrisonController = require '../../src/prisonController'
{MockResponse} = require 'madeye-common'

randomString = -> hat 32, 16

BARE_KEY = "MIGNAoGFMSPtuIfGo5UKVyjQ+NUdGDsVaY/c+Oq4WpbCp7PDisrSzQBwGWTL61ym42aZZpmvCmwM/2kdLJCJF0xWGs+x8Mtn/abfCHnO7lxuYbWN345L9Fn4QZqFvevTy/Ia5vFFU+hd9+HTlmvN6DIjrcXrtnlnRcUaGu2kw5r6SYk3KBGrbNkjJQIDAQAB"
KEY = "-----BEGIN RSA PUBLIC KEY-----\nMIGNAoGFMSPtuIfGo5UKVyjQ+NUdGDsVaY/c+Oq4WpbCp7PDisrSzQBwGWTL61ym\n42aZZpmvCmwM/2kdLJCJF0xWGs+x8Mtn/abfCHnO7lxuYbWN345L9Fn4QZqFvevT\ny/Ia5vFFU+hd9+HTlmvN6DIjrcXrtnlnRcUaGu2kw5r6SYk3KBGrbNkjJQIDAQAB\n-----END RSA PUBLIC KEY-----\n"
KEY_WITHOUT_FIXES = "\nMIGNAoGFMSPtuIfGo5UKVyjQ+NUdGDsVaY/c+Oq4WpbCp7PDisrSzQBwGWTL61ym\n42aZZpmvCmwM/2kdLJCJF0xWGs+x8Mtn/abfCHnO7lxuYbWN345L9Fn4QZqFvevT\ny/Ia5vFFU+hd9+HTlmvN6DIjrcXrtnlnRcUaGu2kw5r6SYk3KBGrbNkjJQIDAQAB\n"

describe 'PrisonController', ->
  prisonController = new PrisonController
  res = null
  beforeEach ->
    res = new MockResponse

  describe '_stripKey', ->
    it 'should return the key if there is no prefix/suffix', ->
      assert.equal prisonController._stripKey(KEY), BARE_KEY
    it 'should strip the key if there is a prefix/suffix', ->
      assert.equal prisonController._stripKey(KEY_WITHOUT_FIXES), BARE_KEY
    it 'should get rid of extraneous line feeds', ->
      keyWithWhitespace = "\n" + KEY + "\n"
      assert.equal prisonController._stripKey(keyWithWhitespace), BARE_KEY
