/* Aroli New Tab — service worker dirigido a evento.
   Sem timers, sem fetch periódico: só reaplica o frame salvo
   quando o navegador inicia ou a extensão instala/atualiza. */
chrome.runtime.onStartup.addListener(applySaved);
chrome.runtime.onInstalled.addListener(applySaved);
chrome.runtime.onMessage.addListener(function (msg) {
  if (msg && msg.aroliRepaint) applySaved();
});

function applySaved() {
  try {
    chrome.storage.local.get("aroli", function (res) {
      var s = (res && res.aroli) || {};
      var mode = s.mode || "system";
      if (mode !== "system") {
        if (s.frame) chrome.theme.update({ colors: s.frame });
        return;
      }
      if (s.frame) {
        // Sistema: o frame da última sessão volta na hora (sem IO);
        // a newtab recém-aberta repinta com o JSON atual e salva.
        chrome.theme.update({ colors: s.frame });
      } else {
        fetch(chrome.runtime.getURL("theme-system.json"), { cache: "no-store" })
          .then(function (r) { return r.ok ? r.json() : null; })
          .then(function (j) {
            if (j && j.colors) chrome.theme.update({ colors: j.colors });
          })
          .catch(function () {});
      }
    });
  } catch (e) { /* storage indisponível: nada a fazer */ }
}
