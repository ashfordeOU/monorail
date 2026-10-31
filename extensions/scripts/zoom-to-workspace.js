// Calls get their own workspace: Zoom, Teams and FaceTime windows move to workspace 3 as they open.
const callApps = ["zoom.us", "Microsoft Teams", "FaceTime", "Webex"]
monorail.on("windowOpened", w => {
  if (callApps.includes(w.app)) monorail.moveToWorkspace(w.id, 3)
})
