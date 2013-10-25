{Logger} = require 'madeye-common'
{Project, File, ActiveDirectory} = require './models'

log = new Logger 'projectCleaner'

CLEANING_INTERVAL = 1*60*60*1000
CLEANING_DOC_LIMIT = 25

cleanProject = (projectId) ->
  File.remove {projectId}, (err) ->
    if err
      log.warn "Error removing files for project #{projectId}", err
    else
      log.trace "Removed files for project #{projectId}"
  ActiveDirectory.remove {projectId}, (err) ->
    if err
      log.warn "Error removing activeDirectories for project #{projectId}", err
    else
      log.trace "Removed activeDirectories for project #{projectId}"

cleanup = ->
  log.debug "Cleaning up old projects"
  Project.find {$lastOpened:{$exists:false}}, null, {limit: CLEANING_DOC_LIMIT},  (err, projects) ->
    if err
      log.warn "Error finding stale projects:", err
      return
    log.trace "Found #{projects.length} projects to clean."

    for project in projects
      cleanProject project._id
      project.remove (err) ->
        if err
          log.warn "Error removing project #{project._id}:", err
        else
          log.trace "Removed project #{project._id}"

log.debug "Starting projectCleaner."
setInterval cleanup, CLEANING_INTERVAL

