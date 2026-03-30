# 小麥注音 for Windows 打包專案

這是一個依賴以下上游專案與資源的 Windows 安裝程式打包專案：

- PIME `1.3.0-stable`
- McBopomofoWeb `2.0.0`
  - 固定 commit：`a488c4d36dcef60ed7f7445798b0597c4c874022`
- ㄅ字嗨字型庫 `bpmfvs`
  - 目前於打包時自動從 GitHub latest release 下載

本專案的目的是讓使用者可以快速打包出適用於 Windows 11 的安裝程式，用來安裝小麥注音輸入法。

目前正式提供的是 `Lite` 安裝包。

## 安裝步驟

### 直接安裝已打包好的安裝程式

1. 取得安裝檔：
   - `release/current/McBopomofo-PIME-Setup-Lite-2026.03.30.10.exe`
2. 在 Windows 11 上執行安裝程式。
3. 依畫面提示完成授權確認與安裝流程。
4. 若安裝時選擇安裝 bpmfvs 字型，安裝程式會一併安裝所需字型。
5. 安裝完成後，可從 Start Menu 開啟：
   - `PIMELauncher`
   - `McBopomofo Config`

### 從原始碼重新打包安裝程式

1. 開啟 PowerShell。
2. 進入專案目錄：

```powershell
cd C:\Users\user\Desktop\project\mcbopomofo
```

3. 安裝建置工具：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\install-build-tools.ps1
```

4. 執行打包：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\build.ps1
```

5. 產生的安裝檔位於：

- `dist\McBopomofo-PIME-Setup-Lite-<version>.exe`
- `dist\artifacts-manifest.txt`

## 交付包

交付用打包包位於：

- `release/current/install_pack.zip`

## 補充

- `workspace`、`build`、`cache`、`dist` 都是工作區或產物，不是專案的正式來源。
- Windows 端對上游內容的調整，主要來自：
  - `installer`
  - `scripts`
  - `upstream-patches`
