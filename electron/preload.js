const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("appUnblocker", {
  selectFile: () => ipcRenderer.invoke("select-file"),
  launchApp: (filePath, macMethod) => ipcRenderer.invoke("launch-app", filePath, macMethod),
  getPlatform: () => ipcRenderer.invoke("get-platform"),
  onLaunchLog: (callback) => {
    const handler = (_event, data) => callback(data);
    ipcRenderer.on("launch-log", handler);
    return () => ipcRenderer.removeListener("launch-log", handler);
  },
});
