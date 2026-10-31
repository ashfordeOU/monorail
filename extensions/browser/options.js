const $ = (id) => document.getElementById(id);
chrome.storage.local.get(["port", "token"]).then(({ port, token }) => { $("port").value = port || ""; $("token").value = token || ""; });
$("save").onclick = async () => {
  await chrome.storage.local.set({ port: Number($("port").value) || 4767, token: $("token").value.trim() });
  $("ok").textContent = "Saved";
};
