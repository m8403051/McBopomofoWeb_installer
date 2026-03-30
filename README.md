# McBopomofo for Windows 安裝包

這個專案用來產生可在 Windows 11 上快速安裝小麥注音輸入法的安裝程式。

專案依賴以下上游內容：
- PIME `1.3.0-stable`
- McBopomofoWeb `2.0.0`
  - 固定 commit：`a488c4d36dcef60ed7f7445798b0597c4c874022`
- bpmfvs 注音字型庫

目前正式提供的是 `Lite` 安裝包。

## 下載

請從 GitHub Releases 下載最新版本：
- Releases 頁面：
  - <https://github.com/m8403051/McBopomofoWeb_installer/releases>
- 目前版本：
  - <https://github.com/m8403051/McBopomofoWeb_installer/releases/tag/v2.0.1>

本次發佈檔案：
- `McBopomofo-PIME-Setup-Lite-2026.03.30.10.exe`
- `install_pack.zip`

## 直接安裝

1. 下載 `McBopomofo-PIME-Setup-Lite-2026.03.30.10.exe`
2. 在 Windows 11 執行安裝程式
3. 依畫面完成授權同意、字型安裝選項與安裝流程
4. 安裝完成後可從 Start Menu 開啟：
   - `PIMELauncher`
   - `McBopomofo Config`

## 從原始碼重新打包

1. 開啟 PowerShell
2. 進入專案目錄

```powershell
cd C:\Users\user\Desktop\project\mcbopomofo
```

3. 安裝建置工具

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\install-build-tools.ps1
```

4. 執行打包

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\build.ps1
```

5. 產物會出現在：
- `dist\McBopomofo-PIME-Setup-Lite-<version>.exe`
- `dist\artifacts-manifest.txt`

## 交付包

可重建用的交付包位置：
- `release\current\install_pack.zip`

## 專案結構

正式來源主要在：
- `installer`
- `scripts`
- `upstream-patches`

以下目錄屬於本地工作區或產物，不作為正式來源：
- `build`
- `cache`
- `dist`
- `tmp`
- `workspace`
