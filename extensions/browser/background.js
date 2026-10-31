// Monorail by Ashforde® browser companion.
// Sends the active tab's site (as the "project") to Monorail's local API, which
// names the workspace after it when Settings → General → Auto-name workspaces is on.
// Set the port and token (from ~/Library/Application Support/Monorail/api-port and api-token) in the options.

async function settings() {
  const { port, token } = await chrome.storage.local.get(["port", "token"]);
  return { port: port || 4767, token: token || "" };
}

async function report(tab) {
  if (!tab || !tab.url || !/^https?:/.test(tab.url)) return;
  const { port, token } = await settings();
  if (!token) return;
  const project = new URL(tab.url).hostname.replace(/^www\./, "");
  try {
    await fetch(`http://127.0.0.1:${port}/context`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify({ project, title: tab.title || "" }),
    });
  } catch (_) {
    // Monorail isn't running or its API is off.
  }
}

chrome.tabs.onActivated.addListener(async ({ tabId }) => report(await chrome.tabs.get(tabId)));
chrome.tabs.onUpdated.addListener((_, change, tab) => { if (change.status === "complete" && tab.active) report(tab); });
