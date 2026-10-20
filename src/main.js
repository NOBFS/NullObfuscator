const tauri = window.__TAURI__;
const invoke = tauri?.core?.invoke;
const appWindow = tauri?.window?.getCurrentWindow();

document.getElementById('minimizeBtn')?.addEventListener('click', async (e) => {
  e.preventDefault();
  if (appWindow) await appWindow.minimize();
});

document.getElementById('maximizeBtn')?.addEventListener('click', async (e) => {
  e.preventDefault();
  if (appWindow) {
    const isMaximized = await appWindow.isMaximized();
    if (isMaximized) {
      await appWindow.unmaximize();
    } else {
      await appWindow.maximize();
    }
  }
});

document.getElementById('closeBtn')?.addEventListener('click', async (e) => {
  e.preventDefault();
  if (appWindow) await appWindow.close();
});

const sakuraContainer = document.getElementById('sakuraContainer');
if (sakuraContainer) {
  for (let i = 0; i < 25; i++) {
    const sakura = document.createElement('div');
    sakura.classList.add('sakura');
    sakura.style.left = `${Math.random() * 100}vw`;
    sakura.style.top = `${Math.random() * -100}vh`;
    sakura.style.animationDuration = `${8 + Math.random() * 7}s`;
    sakura.style.animationDelay = `${Math.random() * 5}s`;
    sakuraContainer.appendChild(sakura);
  }
}

const toast = document.getElementById('toastNotification');
function showToast(message) {
  if (!toast) return;
  toast.textContent = message;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 3000);
}

const input = document.querySelector("#input");
const output = document.querySelector("#output");
const runBtn = document.querySelector("#runBtn");
const loadBtn = document.querySelector("#loadBtn");
const copyBtn = document.querySelector("#copyBtn");
const saveBtn = document.querySelector("#saveBtn");
const inputMeta = document.querySelector("#inputMeta");
const presetSelect = document.querySelector("#presetSelect");
const loadingOverlay = document.getElementById('loadingOverlay');

const updateMeta = () => {
  if (inputMeta && input) inputMeta.textContent = `${input.value.length} chars`;
};

input?.addEventListener("input", updateMeta);
updateMeta();

runBtn?.addEventListener("click", async () => {
  if (!input.value.trim()) {
    showToast("入力が空です");
    return;
  }
  if (!invoke) {
    showToast("Tauri invoke が見つかりません");
    return;
  }

  let preset = presetSelect ? presetSelect.value : "Medium";
  if (preset === "Strong" || preset === "Maximum") {
    preset = "Medium";
  }

  runBtn.disabled = true;
  if (loadingOverlay) loadingOverlay.classList.remove('hidden');
  
  try {
    const result = await invoke("obfuscate_with_prometheus", { 
      source: input.value,
      preset: preset
    });
    output.value = result;
    showToast(`完了 (${preset}): ${result.length} chars`);
  } catch (e) {
    output.value = `-- NullObfuscator\n-- ${e}`;
    showToast("難読化に失敗しました");
  } finally {
    runBtn.disabled = false;
    if (loadingOverlay) loadingOverlay.classList.add('hidden');
  }
});

loadBtn?.addEventListener("click", () => {
  const fileInput = document.createElement("input");
  fileInput.type = "file";
  fileInput.accept = ".luau,.lua";
  fileInput.addEventListener("change", () => {
    const file = fileInput.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      input.value = String(reader.result ?? "");
      updateMeta();
      showToast(`${file.name} を読み込みました`);
    };
    reader.readAsText(file);
  });
  fileInput.click();
});

copyBtn?.addEventListener("click", async () => {
  if (!output.value) return;
  try {
    await navigator.clipboard.writeText(output.value);
    showToast("クリップボードにコピーしました");
  } catch {
    showToast("コピーに失敗しました");
  }
});

saveBtn?.addEventListener("click", async () => {
  if (!output.value) {
    showToast("保存する出力がありません");
    return;
  }
  try {
    await invoke("save_file", { content: output.value });
    showToast("ファイルを保存しました");
  } catch (e) {
    if (String(e).includes("Save cancelled")) {
    } else {
      showToast("保存に失敗しました");
    }
  }
});