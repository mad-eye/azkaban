#TODO: Change Host to Hostname
Settings = {
  bcHost: process.env["MADEYE_BC_HOST"],
  bcPort: process.env["MADEYE_BC_PORT"],
  httpHost: process.env["MADEYE_HTTP_HOST"],
  httpPort: process.env["MADEYE_HTTP_PORT"]
  mongoHost: process.env["MADEYE_MONGO_HOST"],
  mongoPort: process.env["MADEYE_MONGO_PORT"]
  apogeeHost: process.env["MADEYE_APOGEE_HOST"],
  apogeePort: process.env["MADEYE_APOGEE_PORT"]
}

exports.Settings = Settings
