# img2pixel — 像素素材轉換器

截圖 → 像素素材的**單檔離線網頁工具**：去背 → 降解析 → 限色 → 自動產生動畫幀 → 匯出 sprite sheet／ZIP。
零依賴、不用伺服器，**雙擊 `img2pixel.html` 用瀏覽器開就能用**。

## 功能速覽

- **管線**：裁切 → 去背（泛洪／全域色鍵）→ 降解析 → 明暗對比調整 → 去雜點 → k-means 限色（調色盤可鎖定，多幀色彩一致）→ 自動描邊 → 幀位移
- **自動動畫**：走路／飛行（撲翼＋翼模糊殘影）／攻擊／待機／靜物，一鍵生成多幀
- **編輯**：畫筆／橡皮／填色／指抹／直線／吸色／翻轉／自由旋轉（圈選區域）、洋蔥皮、格線、兩列工作列（幀可自由分組）
- **預覽**：滾輪縮放（往自己滾＝放大）、框內拖曳平移、播放（6–12 fps）
- **匯出**：單幅 PNG／水平 sprite sheet／**GIF 動圖**（循環播放）／全部 ZIP（透明背景、1x 真實像素）、調色盤 JSON
- **專案存檔**：存／開 `.json` 專案檔（含全部幀與設定），加上瀏覽器本機**自動存檔**——關掉重開接著上次做
- **匯入 sheet**：把現成的水平 sprite sheet 切成幀重新編輯
- **示範模式**：網址加 `?demo=1` 載入小騎士示範

## 開始使用（Windows）

**雙擊 `img2pixel.bat`**——它是**單一檔案**，內含整套工具（內嵌 `img2pixel.html`）、本機小伺服器與**像素風圖示**：
雙擊後黑色視窗**閃一下就自動消失**（伺服器在背景跑，純 Windows 內建 HttpListener，**不需要 Python**），瀏覽器自動開好工具（網址 `http://localhost:8799/`，port 被占用時自動換下一個）。
**第一次執行會在桌面建立「img2pixel」捷徑**（金色像素龍頭圖示），之後從捷徑開啟更順手。

背景伺服器的生命週期（不用管家）：

- 工具分頁開著＝伺服器活著（頁面每 10 秒自動報平安）
- **關掉分頁／瀏覽器後約 15 分鐘自動收工**
- 想立刻關：工具「專案」區的「**關閉伺服器**」按鈕（單檔版才會出現）
- 診斷紀錄在 `%LOCALAPPDATA%\img2pixel\server.log`

> **為什麼不要直接雙擊 `img2pixel.html`？**
> 用檔案開啟（`file://`）時，Chromium 會把「下載」的檔案標記成 **ZoneId=4（限制的網站）**，Windows 預設**封鎖開啟／解壓縮**（會跳「Windows 已封鎖了對這個檔案的存取」）。
> 走 `http://localhost` 就只會被標成一般網際網路（ZoneId=3），**存檔、解壓都正常**。
> 真的已經被檔案直接開過、做出被封鎖的檔案時：右鍵該檔／該 ZIP →「內容」→ 勾**「解除封鎖」**→ 確定（或 PowerShell `Get-ChildItem 資料夾 | Unblock-File`）。
> macOS／Linux：在資料夾執行 `python3 -m http.server 8799`，再開 `http://127.0.0.1:8799/img2pixel.html`。

### 給維護者

- `img2pixel.bat` 是從 `img2pixel.html` 產生的：改完 HTML 後執行 `build-standalone.ps1`（PowerShell）重新產生；它也會把 `img2pixel.ico` 以 base64 內嵌進 .bat。
- `img2pixel.ico` 由 `draw-ico.js`（Node）從 16×16 手刻像素格產生（多尺寸 BMP frame），改圖示就編輯它的 `GRID` 再重跑。
- HTML 直接雙擊仍然能完整使用，只是匯出檔案會被封鎖（如上）。

## 使用說明

詳見 **[img2pixel-guide.md](img2pixel-guide.md)**（工具內「說明？」按鈕同步同一份內容）。

## 注意

- 匯出檔名規則：`prefix_act_NN.png`（act＝`_still/_walk/_fly/_atk/_idle`，複製幀帶 `c`）
- 工具完全在本機執行、不上傳任何資料（本機伺服器只服務這個資料夾）
