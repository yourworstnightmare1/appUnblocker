const pathInput = document.getElementById("path-input");
const browseBtn = document.getElementById("browse-btn");
const startBtn = document.getElementById("start-btn");
const outputPanel = document.getElementById("output-panel");
const outputLog = document.getElementById("output-log");
const methodMenu = document.getElementById("method-menu");
const methodBtn = document.getElementById("method-btn");
const methodDropdown = document.getElementById("method-dropdown");
const methodOptions = methodDropdown.querySelectorAll(".method-option");

let selectedPath = "";
let macMethod = "folder";
let isMacPlatform = false;

const METHOD_TITLES = {
  folder: "Folder Manipulation",
  gatekeeper: "Gatekeeper Bypass",
  both: "Both",
};

function showOutputPanel() {
  outputPanel.classList.remove("hidden");
}

function clearOutput() {
  outputLog.textContent = "";
}

function appendLogLine(message, level = "info") {
  const line = document.createElement("span");
  line.className = `line ${level}`;
  line.textContent = message;
  outputLog.appendChild(line);
  outputLog.appendChild(document.createTextNode("\n"));
  outputLog.scrollTop = outputLog.scrollHeight;
}

function updateStartState() {
  startBtn.disabled = !selectedPath;
  methodBtn.disabled = !selectedPath;
}

function setMethod(method) {
  macMethod = method;
  const title = METHOD_TITLES[method] || METHOD_TITLES.folder;
  methodBtn.title = title;
  methodBtn.setAttribute("aria-label", `Unblock method: ${title}`);
  methodOptions.forEach((opt) => {
    opt.classList.toggle("selected", opt.dataset.method === method);
  });
}

function closeMethodDropdown() {
  methodDropdown.classList.add("hidden");
  methodBtn.setAttribute("aria-expanded", "false");
}

function openMethodDropdown() {
  methodDropdown.classList.remove("hidden");
  methodBtn.setAttribute("aria-expanded", "true");
}

function toggleMethodDropdown() {
  if (methodDropdown.classList.contains("hidden")) {
    openMethodDropdown();
  } else {
    closeMethodDropdown();
  }
}

window.appUnblocker.onLaunchLog(({ message, level }) => {
  appendLogLine(message, level);
});

methodBtn.addEventListener("click", (e) => {
  e.stopPropagation();
  toggleMethodDropdown();
});

methodOptions.forEach((option) => {
  option.addEventListener("click", (e) => {
    e.stopPropagation();
    setMethod(option.dataset.method);
    closeMethodDropdown();
  });
});

methodMenu.addEventListener("click", (e) => e.stopPropagation());

document.addEventListener("click", () => {
  closeMethodDropdown();
});

browseBtn.addEventListener("click", async () => {
  try {
    const filePath = await window.appUnblocker.selectFile();
    if (!filePath) return;
    selectedPath = filePath;
    pathInput.value = filePath;
    updateStartState();
  } catch (err) {
    showOutputPanel();
    appendLogLine(err.message || "Could not open file picker.", "error");
  }
});

startBtn.addEventListener("click", async () => {
  if (!selectedPath) return;

  startBtn.disabled = true;
  browseBtn.disabled = true;
  methodBtn.disabled = true;
  closeMethodDropdown();
  showOutputPanel();
  clearOutput();

  try {
    await window.appUnblocker.launchApp(selectedPath, isMacPlatform ? macMethod : undefined);
  } catch {
    /* errors already logged from main process */
  } finally {
    browseBtn.disabled = false;
    updateStartState();
  }
});

window.appUnblocker.getPlatform().then(({ isWindows, isMac }) => {
  isMacPlatform = isMac;
  pathInput.placeholder = isWindows ? "Select an .exe…" : "Select an application…";
  if (isMac) {
    methodMenu.classList.remove("hidden");
    methodBtn.disabled = true;
  }
});
