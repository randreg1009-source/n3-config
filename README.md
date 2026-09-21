# n3-config

N3 下載器 / 安裝器讀取的**遠端配置**存放處（公開 repo，走 `raw.githubusercontent.com` + jsDelivr 鏡像）。
配置內容只有「檔名 / 版本 / 大小 / 雜湊 / 下載來源」，不含任何機密；實際安全由**每個套件都要有 MD5 或 SHA-256**
（並已由 RSA-2048/SHA-256 簽章保護）保證，所以放在公開空間是可接受的。

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

## 怎麼改下載連結（四種情境，差別只有中間那步）

會動到的檔案：`n3-packages.json`（生效配置，**要簽**）、`n3-packages.json.sig`（工具產生的簽章，**必須與配置同一個 commit**）、
`sign.cmd` / `check-sig.cmd` / `publish.cmd`。私鑰在 `C:\Users\Foresee\n3-keys\n3di-config-sign.pem`，passphrase 只有你知道。

在 CMD 裡先把執行檔路徑存成變數（同一個視窗之後重複用，不必每次貼長路徑）：
```
set NDI=D:\N3_D3D11\DownloaderInstaller\out\Release\N3DownloaderInstaller.exe
```
下面所有 `%NDI%` 就是指它。文章裡的 `<...>` 是「請換成實際值」的佔位記號，**不要連尖括號一起輸入**
（CMD 把 `<` 當成輸入重導向，打進去會變成別的意思）。

先確定你在做哪一種：

| 情境 | 要改的欄位 | 雜湊要不要重算 |
|---|---|---|
| **A. 同一個檔、換一條連結**（換網域或重新分享同一份內容） | 該套件的 `sources[].url`（可以多掛幾條當備源） | **不用** — 內容沒變，`size`/`md5`/`sha256` 全部留原值 |
| **B. 換成新版檔案**（內容變了） | 上傳新檔 → 改 `version`、`size`、`md5`、`sha256`、`sources[].url`；安裝後要查的關鍵檔若有變，`requiredFiles` 也要改 | **一定要重算**（第 2 步） |
| **C. 新增一個套件** | 從 `n3-packages.template.json` 複製一整筆進 `packages`，逐欄位填實值 | 新檔當然要算 |
| **D. 停用／撤掉一個套件** | 優先把該筆 `required` 改成 `false`（保留 `id` 讓舊版客戶端仍認得）；真的要拿掉就刪整筆 | 不需 |

### 標準流程（每一步都有它擋得住的錯誤）

1. 編輯 `n3-packages.json`。
   - `id` 是唯一鍵，**不要出現兩筆相同 id**；舊客戶端認的是 `id`，改 `id` 等於換一個套件。
   - `name` 只能是純檔名（不帶目錄、不含 `/` 或反斜線），它同時是快取裡的檔名。
   - `sources` 是**陣列**：順序只是備源順序，安裝器會先測速再挑「最快且可用」的源；同一條失敗會退避重試（1/2/4 秒）三次才換下一條。
   - 連結寫法：MEGA 一定要把 `#` 後面的金鑰一起留著（`https://mega.nz/file/XXXX#KEY`）；Google Drive 用
     `https://drive.google.com/uc?id=<ID>`；MediaFire 用原樣分享連結；你自己網域的直連也支援。
   - `archiveType` 只能是 `7z` / `zip` / `exe` / `none`。`none`／`exe` 不會被解壓，**快取裡那份就是安裝結果**。
   - `requiredFiles` 可以用相對子路徑（例：`Data\Config.ini`）；結尾加分隔符（例：`Data/`）代表「必須是目錄」。
     絕對路徑、磁碟機代號、`..` 一律被 CFG018 拒收。
2. 算雜湊（情境 B/C 必做，A 可跳）——**用你即將上傳的那一份檔算**，不是用瀏覽器抓來的半成品：
   ```
   certutil -hashfile <你的檔名，例 N3Client.7z> MD5
   certutil -hashfile <同一個檔> SHA256
   ```
   兩值轉小寫貼進去（`md5` 32 字元、`sha256` 64 字元）。兩個都填就會兩項都驗；一個都不填會被安裝器直接拒絕。
3. 推送前先本地驗格式（這時還沒簽章，快速失敗）：
   ```
   %NDI% --validate-config n3-packages.json
   ```
   確認 `結論: 配置可接受`，且任務清單的 `installOrder` 順序、每個下載源與落地路徑都如你所想。
   出現任何 `ERROR`（`CFGnnn`）整份會被拒 —— 照說明修，不要放過。
4. **真的抓一次**，這一步才算驗到連結：
   ```
   %NDI% --run n3-packages.json --cache %TEMP%\n3check --only <套件的 id，例如 smoketest> --no-skip
   ```
   - `--no-skip` 是重點：不加它、快取裡還有舊檔時會直接跳過下載，等於沒測。
   - 大檔可以加 `--limit-ms 8000` 只跑幾秒，看解析與傳輸是否真的啟動（會留 `.cldpart`，測完把 `%TEMP%\n3check` 刪掉）。
   - 只想核對雜湊：`--verify-file <檔案> --sha256 <期望的 64 字元雜湊>`。
   - MEGA 測速只做 `HEAD`／`bytes=0-0` 等級，**匿名配額是共享而且很容易被耗盡**；要實測大檔請排在最後，或改用 GDrive／自建源。
5. 重簽（這一步會先把配置正規化成 LF 再簽，之後別再用編輯器亂改行尾）：
   ```
   set N3DI_KEYDIR=C:\Users\Foresee\n3-keys
   sign.cmd <比上次大的 serial，例如 2>
   ```
   `serial` 是整數且**只能變大**（必須比客戶端用過的大）。它跟「內容」綁在一起動：改了內容卻不換 serial，
   防降級與快取命中判斷就會被繞過，所以工具把兩件事合成一步。
6. 用第二個實作交叉驗一次（不依賴我們的 exe）：
   ```
   check-sig.cmd
   ```
   必須看到 `Verified OK` 與 `signature is valid for this config`。
7. 推送（配置與 `.sig` 會進同一個 commit）：
   ```
   publish.cmd "client 1.0.26 (new MediaFire link)"
   ```
8. 推完用**線上位址**再驗一次 —— 那才是客戶端會看到的東西（兩個鏡像都測）：
   ```
   %NDI% --validate-config https://raw.githubusercontent.com/randreg1009-source/n3-config/main/n3-packages.json
   %NDI% --validate-config "https://cdn.jsdelivr.net/gh/randreg1009-source/n3-config@main/n3-packages.json"
   ```
   兩邊都 `rc=0` 才算收工。

### 發佈後的快取與踩過的坑

- `raw.githubusercontent.com` 與 jsDelivr 都可能**短暫服務舊內容**。急著驗證時把 `@main` 換成剛推的 commit SHA
  （`…/n3-config@<SHA>/n3-packages.json`）就能拿到確定版本；`check-sig.cmd` 驗的就是「位元組有沒有被換掉」。
- **絕對不要只推配置、不推 `.sig`**（或反過來）：內建公鑰的安裝器看到缺簽章的線上配置會直接拒收（rc=2），
  這是設計目的，不是可以饒過的警告。
- **不要手改 `.sig`**，也不要為了「讓它過」而去動 `minConfigSerial`；該做的是把 serial 往上加並重簽。
- `.gitattributes` 是這套流程能成立的前提（`*.json`/`*.sig` 標 `-text`）。若哪天有人把它移除或改成 `text`，
  git 的 `core.autocrlf` 會把行尾改掉，**簽章就會在 push 後全盤失效** —— 這已經發生過一次，別讓它第二次發生。
- 只改 `README.md`、範本註解這類**非簽章涵蓋的檔案**：不需要重簽，直接 `publish.cmd` 就好
  （簽章只蓋 `n3-packages.json` 這一個檔的位元組）。

## 三條紀律

1. **不要刪除已發佈過的檔案/commit**：舊版安裝器還在取同一個 URL，刪掉會全部紅。要撤版本就
   `git revert` 或把檔案改回上一版內容再推，而不是把檔拿掉。
3. **先推配置+簽章，再發新安裝器**：安裝器內建公鑰之後，「線上沒有 `.sig` 的配置」會被拒收（不是警告）。所以發佈順序一定是：`sign.cmd` → 兩檔同 commit 推送 → 才換上內建公鑰的安裝器。
2. **雜湊是唯一判斷標準**：不要用檔名、大小、修改時間判斷新舊；`version` 只给人看。
3. 這個 repo 是**公開**的：不要在此放 token、私鑰、帳號、內網網域。RSA 私鑰永遠不進這裡。
