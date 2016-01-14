lib = require '../lib/index.coffee'

callbacks = []

robot = {
  respond: (regex, cb) ->
    callbacks.push cb
}

lib(robot)

for cb in callbacks
  cb({
    reply: console.log
    match: [ "feed me tomorrow", "tomorrow" ]
  })
