// Focus hours: Focus mode on while you're in the "Deep" workspace, a notice when you leave it.
monorail.on("workspaceChanged", ws => {
  if (ws.name === "Deep") { monorail.perform("focus-mode"); monorail.notify("Deep work time") }
})
