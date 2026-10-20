(function() {
  const tauriApi = window.__TAURI__;

  window.checkForUpdates = async function(isManual = false) {
    const updater = tauriApi?.updater;
    if (!updater) {
      if (isManual && window.showToast) window.showToast("アップデータが見つかりません");
      return;
    }

    try {
      const update = await updater.check();
      if (update) {
        const banner = document.getElementById('updateBanner');
        const versionText = document.getElementById('updateVersion');
        const updateBtn = document.getElementById('updateBtn');
        const closeBtn = document.getElementById('updateCloseBtn');

        if (versionText) versionText.textContent = `v${update.version.replace(/^v/, '')}`;
        if (banner) banner.classList.add('show');

        if (updateBtn) {
          const newUpdateBtn = updateBtn.cloneNode(true);
          updateBtn.parentNode.replaceChild(newUpdateBtn, updateBtn);
          
          newUpdateBtn.addEventListener('click', async () => {
            newUpdateBtn.disabled = true;
            newUpdateBtn.textContent = "更新中...";
            try {
              const cleanVersion = update.version.replace(/^v/, '');
              const notes = update.body || "最新のアップデートです。";

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
              newUpdateBtn.disabled = false;
              newUpdateBtn.textContent = "更新する";
            }
          });
        }

        if (closeBtn) {
          const newCloseBtn = closeBtn.cloneNode(true);
          closeBtn.parentNode.replaceChild(newCloseBtn, closeBtn);
          newCloseBtn.addEventListener('click', () => {
            banner?.classList.remove('show');
          });
        }
      } else {
        if (isManual && window.showToast) {
          window.showToast("最新バージョンです");
        }
      }
    } catch (error) {
      console.error("Update check failed:", error);
      if (isManual && window.showToast) {
        window.showToast("アップデートの確認に失敗しました");
      }
    }
  };

  async function checkUpdateComplete() {
    const pendingVersion = localStorage.getItem('pending_update_version');
    const pendingNotes = localStorage.getItem('pending_update_notes');

    if (pendingVersion && tauriApi?.app?.getVersion) {
      try {
        const currentVersion = await tauriApi.app.getVersion();
        const cleanCurrentVersion = currentVersion.replace(/^v/, '');

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

          const modalCloseBtn = document.getElementById('closeModalBtn');
          const modalOkBtn = document.getElementById('modalOkBtn');

          if (modalCloseBtn) {
            const newClose = modalCloseBtn.cloneNode(true);
            modalCloseBtn.parentNode.replaceChild(newClose, modalCloseBtn);
            newClose.addEventListener('click', closeModal);
          }
          if (modalOkBtn) {
            const newOk = modalOkBtn.cloneNode(true);
            modalOkBtn.parentNode.replaceChild(newOk, modalOkBtn);
            newOk.addEventListener('click', closeModal);
          }
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
    setTimeout(() => window.checkForUpdates(false), 3000);

    const checkBtn = document.getElementById('checkUpdateBtn');
    if (checkBtn) {
      checkBtn.addEventListener('click', async () => {
        checkBtn.classList.add('spinning');
        await window.checkForUpdates(true);
        checkBtn.classList.remove('spinning');
      });
    }
  });
})();