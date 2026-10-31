// Monorail by Ashforde® for VS Code (and Cursor, Windsurf…): reports the open
// project and file to Monorail's local API, so the workspace takes the project's name.
const vscode = require("vscode");
const http = require("http");

function report() {
  const config = vscode.workspace.getConfiguration("monorail");
  const token = config.get("token");
  if (!token) return;
  const folder = vscode.workspace.workspaceFolders?.[0]?.name || "";
  const file = vscode.window.activeTextEditor?.document?.fileName || "";
  const body = JSON.stringify({ project: folder, file });
  const request = http.request({
    host: "127.0.0.1", port: config.get("port"), path: "/context", method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, "Content-Length": Buffer.byteLength(body) },
  });
  request.on("error", () => {});
  request.end(body);
}

function activate(context) {
  report();
  context.subscriptions.push(vscode.window.onDidChangeActiveTextEditor(report), vscode.workspace.onDidChangeWorkspaceFolders(report));
}

module.exports = { activate, deactivate() {} };
