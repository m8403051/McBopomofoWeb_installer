# McBopomofo for Windows Lite

`Lite` 是目前正式提供的版本。

內容包含：

- PIME runtime
- McBopomofoWeb backend
- bpmfvs 注音字型安裝流程

目前不包含：

- 其他 PIME 輸入法
- `Full` 規劃中的額外整合內容

## 安裝內容

安裝程式會：

1. 展開 PIME runtime 與 McBopomofo payload
2. 註冊 PIME 相關元件
3. 安裝 Start Menu 項目
4. 依使用者選擇安裝 bpmfvs 字型
5. 建立 McBopomofo 設定入口

## 設定與資料位置

使用者設定檔位置：

- `%APPDATA%\PIME\mcbopomofo\config.json`

安裝目錄：

- `%ProgramFiles(x86)%\PIME`

## 授權與來源

安裝程式會顯示並要求同意以下上游專案或資源的授權：

- McBopomofoWeb
- PIME
- bpmfvs 字型

## 建置與交付

若要重建安裝檔，請參考：

- `BUILD.md`

交付用 build 包位於：

- `release\current\install_pack.zip`
