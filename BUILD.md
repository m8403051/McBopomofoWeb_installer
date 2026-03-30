# BUILD

## 目前定位

目前正式維護的是 `Lite` 安裝包：

- 產出 `McBopomofo-PIME-Setup-Lite-<version>.exe`
- 內容包含：
  - PIME runtime
  - McBopomofoWeb `build:pime` 輸出
  - bpmfvs 注音字型安裝流程
- 不包含其他 PIME 輸入法

`Full` 目前只保留為未來規劃名稱，暫不製作。

## 上游來源

打包時會使用兩個上游來源：

- `McBopomofoWeb`
  - 來源：GitHub 上游 repo
  - 目前固定 commit：
    - `a488c4d36dcef60ed7f7445798b0597c4c874022`
  - 本專案會在 clone 後套用：
    - `upstream-patches\McBopomofoWeb`
- `PIME`
  - 來源：預編譯 runtime / 官方安裝包解包內容
  - 本專案不直接修改上游 binary
  - 整合修改發生在 installer 與 build 流程

## 建置前置工具

先在 PowerShell 執行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\install-build-tools.ps1
```

此步驟會準備：

- `git`
- `node`
- `npm`
- `makensis`
- `7z`

## 建置方式

在專案根目錄執行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\build.ps1
```

可選參數範例：

```powershell
.\scripts\build.ps1 `
  -Version "2026.03.30.10" `
  -ExpectedMcBopomofoWebCommit "a488c4d36dcef60ed7f7445798b0597c4c874022"
```

## 建置流程摘要

`build.ps1` 目前會：

1. 準備 `workspace`
2. 取得或更新 `McBopomofoWeb`
3. 套用 `upstream-patches\McBopomofoWeb`
4. 執行 `npm run build:pime`
5. 準備 PIME runtime
6. 下載 bpmfvs 字型資源
7. 組裝 installer staging
8. 產出 `Lite` 安裝檔

## 產物位置

最新建置產物在：

- `dist\McBopomofo-PIME-Setup-Lite-<version>.exe`
- `dist\artifacts-manifest.txt`

舊版產物會移到：

- `dist\archive\...`

## 交付包

交付用 build 包在：

- `release\current\install_pack`
- `release\current\install_pack.zip`

## 主要來源檔

- `scripts\build.ps1`
- `installer\McBopomofoPIME.nsi`
- `installer\helpers\install-fonts.ps1`
- `installer\helpers\uninstall-fonts.ps1`
- `installer\helpers\set-config-flag.ps1`
- `scripts\install-build-tools.ps1`
- `scripts\uninstall-build-tools.ps1`
- `scripts\manual-validate-deploy.ps1`
- `upstream-patches\McBopomofoWeb`

## 備註

- `workspace`、`build`、`cache`、`dist` 都屬於可重建工作區或產物，不是 source of truth。
- 上游 patch 與整合方式請參考：
  - `patch.md`
- 主要檔案分類請參考：
  - `files.md`
