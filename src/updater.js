const tauri = window.__TAURI__;

async function checkForUpdates() {
  const updater = window.__TAURI__?.updater;
  if (!updater) return;

  try {
    const update = await updater.check();
    if (update) {
      const banner = document.getElementById('updateBanner');
      const versionText = document.getElementById('updateVersion');
      const updateBtn = document.getElementById('updateBtn');
      const closeBtn = document.getElementById('updateCloseBtn');

      if (versionText) versionText.textContent = `v${update.version.replace(/^v/, '')}`;
      if (banner) banner.classList.add('show');

      updateBtn?.addEventListener('click', async () => {
        updateBtn.disabled = true;
        updateBtn.textContent = "更新中...";
        try {
          const cleanVersion = update.version.replace(/^v/, '');
          const notes = update.body || "最新のアップデートです。";
          
          console.log("Updater notes:", notes);
          
          localStorage.setItem('pending_update_version', cleanVersion);
          localStorage.setItem('pending_update_notes', notes);

          await update.downloadAndInstall((event) => {
            if (event.event === 'Finished') {
              window.__TAURI__.process.relaunch();
            }
          });
        } catch (e) {
          console.error(e);
          if (window.showToast) window.showToast("アップデートに失敗しました");
          updateBtn.disabled = false;
          updateBtn.textContent = "更新する";
        }
      });

      closeBtn?.addEventListener('click', () => {
        banner?.classList.remove('show');
      });
    }
  } catch (error) {
    console.error("Update check failed:", error);
  }
}

async function checkUpdateComplete() {
  const pendingVersion = localStorage.getItem('pending_update_version');
  const pendingNotes = localStorage.getItem('pending_update_notes');

  if (pendingVersion && tauri?.app?.getVersion) {
    try {
      const currentVersion = await tauri.app.getVersion();
      const cleanCurrentVersion = currentVersion.replace(/^v/, '');
      
      console.log("Pending:", pendingVersion, "Current:", cleanCurrentVersion);

      if (pendingVersion === cleanCurrentVersion) {
        const modal = document.getElementById('updateCompleteModal');
        const modalVersion = document.getElementById('modalVersion');
        const modalNotes = document.getElementById('modalNotes');
        
        if (modalVersion) modalVersion.textContent = `v${cleanCurrentVersion}`;
        if (modalNotes) modalNotes.textContent = pendingNotes || '特に記載はありません。';
        if (modal) modal.classList.remove('hidden');

        const closeModal = () => {
          if (modal) modal.classList.add('hidden');
          localStorage.removeItem('pending_update_version');
          localStorage.removeItem('pending_update_notes');
        };

        document.getElementById('closeModalBtn')?.addEventListener('click', closeModal);
        document.getElementById('modalOkBtn')?.addEventListener('click', closeModal);
      } else {
        localStorage.removeItem('pending_update_version');
        localStorage.removeItem('pending_update_notes');
      }
    } catch (e) {
      console.error("Failed to check update complete:", e);
    }
  }
}

window.addEventListener('DOMContentLoaded', () => {
  checkUpdateComplete();
  setTimeout(checkForUpdates, 3000);
});