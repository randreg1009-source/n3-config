# n3-config

N3 下載器 / 安裝器讀取的**遠端配置**存放處（公開 repo，走 `raw.githubusercontent.com` + jsDelivr 鏡像）。
配置內容只有「檔名 / 版本 / 大小 / 雜湊 / 下載來源」，不含任何機密；實際安全由**每個套件都要有 MD5 或 SHA-256**
（並即將加上 RSA 簽章）保證，所以放在公開空間是可接受的。

## 取用位置（安裝器的引導清單就填這幾條）

| 順序 | URL | 用途 |
|---|---|---|
| 1（主源） | `https://raw.githubusercontent.com/randreg1009-source/n3-config/main/n3-packages.json` | 直接讀 git 分支最新內容 |
| 2（鏡像） | `https://cdn.jsdelivr.net/gh/randreg1009-source/n3-config@main/n3-packages.json` | 主源被擋/慢時改用 CDN |
| 3（鎖版本） | `https://cdn.jsdelivr.net/gh/randreg1009-source/n3-config@<commit SHA>/n3-packages.json` | 需要「永遠取到同一版」時用 |

實測（本機 2026-09-20）：取 raw **200 / 0.37s**、取 jsDelivr **200 / 0.24s**；`raw` 的快取標頭是
`Cache-Control: max-age=300` → **推送後大約 5 分鐘內生效**，急著驗證就加一個查詢參數（如 `?t=1`）或改取 jsDelivr 的另一版本路徑。

## 檔名與角色

- `n3-packages.json` —— **線上生效的配置**（安裝器唯一會抓的檔案）。目前只掛一筆 `smoketest`，用途是把
  「抓取 → 嚴格式校驗 → 下載 → 雜湊複驗 → 進快取」這條鏈路保持在**可随时验证**的状态；真實套件上線後照範本追加即可。
- `n3-packages.template.json` —— 真實套件（client / resource / update）的欄位範本，`REPLACE_ME` 那些**不會**被安裝器讀取。
- `n3di.settings.sample.json` —— 放進**安裝器目錄**用的引導清單範本（改名成 `n3di.settings.json` 放在 exe 旁邊）。

## 每次發佈新版本的做法

1. 把新套件上傳到雲盤，取「分享連結」（MEGA 要連 `#` 後面的金鑰一起複製）。
2. 算雜湊（同一台機器、同一個檔案）：
   ```
   certutil -hashfile N3Client.7z MD5
   certutil -hashfile N3Client.7z SHA256
   ```
   兩值都轉成小寫貼進配置（`md5` 32 字元、`sha256` 64 字元）。
3. 編輯 `n3-packages.json`：改 `version`、`size`、雜湊、`sources`；**新增加套件就新增一筆，不要改到別人还在用的 id**。
4. 本地先驗（不用等推送）：
   ```
   "D:\N3_D3D11\DownloaderInstaller\out\Release\N3DownloaderInstaller.exe" --validate-config n3-packages.json
   ```
   看到 `結論: 配置可接受` + 正確的任務清單才推。有 `ERROR` 就照 `CFGnnn` 的說明修（任何一項 Error 都會讓整份配置被拒）。
5. 推送：
   ```
   publish.cmd "client 1.0.26"
   ```
   （或自己 `git add -A && git commit -m "…" && git push`。）

## 三條紀律

1. **不要刪除已發佈過的檔案/commit**：舊版安裝器還在取同一個 URL，刪掉會全部紅。要撤版本就
   `git revert` 或把檔案改回上一版內容再推，而不是把檔拿掉。
2. **雜湊是唯一判斷標準**：不要用檔名、大小、修改時間判斷新舊；`version` 只给人看。
3. 這個 repo 是**公開**的：不要在此放 token、私鑰、帳號、內網網域。RSA 私鑰永遠不進這裡。
