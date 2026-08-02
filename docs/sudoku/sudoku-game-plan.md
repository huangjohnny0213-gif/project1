# 數獨遊戲（C# 主控台版 + Access 資料庫）開發規劃

> **文件版本**：1.0
> **建立日期**：2026-08-02
> **目標**：一個單機執行的 C# 數獨遊戲，遊戲進度存在本機 Access (.accdb) 資料庫

---

## 0. 一分鐘總覽

| 項目 | 決定 |
|---|---|
| 執行型態 | 本機單機、主控台（Console）介面 |
| 語言 / 框架 | C# 12 / .NET 8（`net8.0-windows`） |
| 資料庫 | Microsoft Access `.accdb` |
| 資料存取 | ADO.NET + `System.Data.OleDb`（NuGet 套件）+ ACE OLEDB 驅動 |
| 建資料庫方式 | 手動在 Access 依 `schema.sql` 建表（本次選定） |
| 架構分層 | `Core`（規則）→ `Data`（存取）→ `ConsoleApp`（介面） |
| 測試 | xUnit，針對規則 / 求解器 / 產生器 |

**開發順序建議**：先做 §3 的資料庫 → §4 的遊戲規則（可先用假資料在 Console 跑）→ §5 的資料存取 → §6 的介面 → 串起來。
規則邏輯與資料庫互不相依，可以平行進行。

---

## 1. 前置環境準備

### 1.1 必裝軟體

1. **.NET 8 SDK** — <https://dotnet.microsoft.com/download>
2. **Visual Studio 2022 / 2026 Community**（或 VS Code + C# Dev Kit）
3. **Microsoft Access Database Engine 2016 Redistributable**
   — 這是關鍵。沒有它，C# 程式連不上 `.accdb`。
   已安裝完整版 Microsoft Access 的話通常已內含。

### 1.2 ⚠️ 位元數（32/64-bit）必須一致 — 最常見的踩雷點

`Microsoft.ACE.OLEDB.12.0 provider is not registered on the local machine` 這個錯誤，
九成是位元數不合造成的。規則：

> **你的程式的位元數，必須跟你安裝的 Access Database Engine 位元數相同。**

| 你安裝的 Access / ACE | 專案設定 |
|---|---|
| 64 位元 | `<PlatformTarget>x64</PlatformTarget>` |
| 32 位元 | `<PlatformTarget>x86</PlatformTarget>` |

.NET 8 主控台專案預設是 AnyCPU，在 64 位元 Windows 上會以 64 位元執行。
如果你裝的是 32 位元 Office，就務必在 `.csproj` 明確指定 `x86`。

檢查方式：控制台 →「程式和功能」看 Office / Access Database Engine 的版本字樣。

### 1.3 平台限制（先講清楚）

- `System.Data.OleDb` 與 ACE 驅動 **只能在 Windows 執行**。這個遊戲不會跨平台。
- 這是選用 Access 的必然結果，不是架構缺陷。
- 若日後想跨平台或想免安裝驅動，唯一要換的是 `Sudoku.Data` 這一層（改用 SQLite），
  `Sudoku.Core` 與 `Sudoku.ConsoleApp` 完全不用動 —— 這也是下面要分層的主要理由。

---

## 2. 專案結構

```
src/csharp/
├── SudokuGame.sln
├── Sudoku.Core/                    ← 遊戲規則，零外部相依、可單獨測試
│   ├── Models/
│   │   ├── Board.cs                    盤面（81 格）
│   │   ├── Cell.cs                     單格（值、是否為題目給定、候選數）
│   │   ├── Move.cs                     一步操作
│   │   ├── Difficulty.cs               難度列舉
│   │   └── GameSession.cs              一場遊戲的完整狀態
│   ├── Rules/
│   │   ├── SudokuValidator.cs          合法性檢查（列/行/宮）
│   │   └── BoardSerializer.cs          Board ⇄ 81 字元字串
│   ├── Solving/
│   │   ├── SudokuSolver.cs             回溯求解 + 解的個數計算
│   │   └── SudokuGenerator.cs          產生唯一解的題目
│   ├── GameEngine.cs                   對外唯一入口：下子、清除、復原、提示
│   └── Abstractions/                   Repository 介面（介面放這，實作放 Data）
│       ├── IPlayerRepository.cs
│       ├── IPuzzleRepository.cs
│       └── IGameSessionRepository.cs
│
├── Sudoku.Data/                    ← Access 資料存取
│   ├── AccessConnectionFactory.cs      連線字串 / 建立 OleDbConnection
│   ├── DbHealthCheck.cs                啟動時檢查 .accdb 與驅動是否就緒
│   ├── Repositories/
│   │   ├── AccessPlayerRepository.cs
│   │   ├── AccessPuzzleRepository.cs
│   │   └── AccessGameSessionRepository.cs
│   └── appsettings.json                連線字串、DB 檔案路徑
│
├── Sudoku.ConsoleApp/              ← 主控台介面
│   ├── Program.cs                      進入點、組裝相依物件
│   ├── Menus/
│   │   ├── MainMenu.cs                 主選單
│   │   ├── NewGameFlow.cs              選難度 → 產生題目 → 開新局
│   │   ├── LoadGameFlow.cs             列出存檔 → 載入
│   │   └── StatsView.cs                統計畫面
│   ├── Rendering/
│   │   └── BoardRenderer.cs            把 Board 畫成文字盤面（含顏色）
│   ├── Input/
│   │   └── CommandParser.cs            把玩家輸入解析成指令物件
│   └── GameLoop.cs                     遊戲主迴圈
│
└── Sudoku.Tests/                   ← xUnit 單元測試
    ├── ValidatorTests.cs
    ├── SolverTests.cs
    ├── GeneratorTests.cs
    └── SerializerTests.cs
```

### 相依方向（單向，不可反向）

```
ConsoleApp ──► Core ◄── Data
     └──────────────────► Data（只在 Program.cs 組裝時參照）
```

- `Core` **不認識** Access、不認識 Console，只有純邏輯。
- `Data` 參照 `Core`（實作 `Core/Abstractions` 的介面、使用 `Core` 的模型）。
- `ConsoleApp` 在 `Program.cs` 把 `Access*Repository` 注入 `GameEngine`，其餘程式碼只依賴介面。

---

## 3. 資料庫設計

完整可執行的 DDL 在 **[`schema.sql`](./schema.sql)**，本節說明設計理由。

### 3.1 ER 概念

```
Players ──1:N──► GameSessions ──N:1──► Puzzles
                       │
                       └──1:N──► Moves
```

- **Puzzles**：題目本身（題面 + 標準解答）。同一題可以被玩很多次 → 獨立成表，不重複儲存。
- **GameSessions**：一次遊玩＝一筆存檔。這是「儲存遊戲進度」的核心。
- **Moves**：每一步操作，用於復原/重做與統計。（見 §3.4 的取捨）

### 3.2 盤面的儲存格式

**用 81 個字元的字串**，由左上往右下逐列展開，`'1'`~`'9'` 是數字、`'0'` 是空格。

```
第 0 格 = (row 0, col 0)      cellIndex = row * 9 + col
"530070000600195000098000060800060003400803001700020006060000280000419005000080079"
```

理由：
- Access `TEXT(255)` 放得下，讀寫只要一次，不必為 81 格開 81 個欄位或 81 筆資料列。
- 人眼可讀，方便直接在 Access 裡除錯。
- C# 端 `BoardSerializer` 一行就能來回轉換。

**候選數筆記**（玩家自己標的「這格可能是 1/2/5」）放在 `NotesJson`（LONGTEXT）：

```json
{"0":[1,2,5],"34":[7,9]}
```

用 `System.Text.Json` 序列化 `Dictionary<int, List<int>>` 即可。

### 3.3 資料表一覽

| 資料表 | 用途 | 關鍵欄位 |
|---|---|---|
| `SchemaInfo` | 結構版本，未來升級用 | `SchemaVersion` |
| `Players` | 玩家 | `PlayerId`, `PlayerName` |
| `Puzzles` | 題目庫 | `Givens`(81), `Solution`(81), `Difficulty` |
| `GameSessions` | **存檔** | `CurrentBoard`(81), `NotesJson`, `ElapsedSeconds`, `SessionStatus` |
| `Moves` | 操作紀錄 | `CellIndex`, `OldValue`, `NewValue`, `MoveKind` |
| `PlayerStats` | 統計快取（可選） | `BestSeconds`, `ClearedCount` |

`SessionStatus` 三種值：`InProgress`（可續玩）、`Completed`（已完成）、`Abandoned`（放棄）。

### 3.4 一個要先做的取捨：`Moves` 表要不要即時寫入？

| 做法 | 優點 | 缺點 | 建議 |
|---|---|---|---|
| A. 每下一步就 INSERT | 當機也不遺失 | 每步一次 I/O，Access 會慢 | ❌ |
| B. 復原堆疊放記憶體，存檔時才整批寫入 | 遊玩順暢 | 未存檔前當機會遺失 | ✅ **採用** |
| C. 完全不存 Moves | 最簡單 | 沒有復原歷史與行為統計 | 先做 B，若嫌煩再退成 C |

採 B：`GameEngine` 內部用 `Stack<Move>` 管理復原/重做，
存檔時把新增的 Move 用**一個交易**批次寫入。

### 3.5 Access 的六個地雷（寫 SQL 前務必知道）

1. **不支援 SQL 註解**（`--`、`/* */`）。貼進 Access 查詢視窗時要把註解拿掉。
2. **一次只能執行一句 DDL**。要一句一句貼、一句一句執行。
3. **DDL 不支援 `DEFAULT` 與 `CHECK`**（在 Access UI 的 ANSI-89 模式下）。
   → 所有預設值與值域檢查（例如 `NewValue` 只能 0~9）**改由 C# 負責**。
4. **參數是位置式的 `?`**，不是具名參數。
   `AddWithValue("@id", x)` 裡的名字會被忽略，**加入順序必須跟 SQL 中 `?` 的出現順序完全一致**。
5. **保留字**（`Date`, `Value`, `Level`, `Name`, `Order`, `Password`, `User`, `Count`, `Index`…）
   當欄位名要用 `[中括號]` 包起來。本 schema 已刻意避開（用 `CreatedAt`、`NewValue`、`Difficulty`）。
6. **取得剛插入的自動編號**要用 `SELECT @@IDENTITY`，
   而且必須在**同一個尚未關閉的 `OleDbConnection`** 上執行，否則抓不到。

### 3.6 建立資料庫的實際步驟

1. 開啟 Microsoft Access →「空白資料庫」→ 檔名 `SudokuGame.accdb`
   → 存到專案的 `src/csharp/data/` 目錄（此目錄要加進 `.gitignore`）。
2. 「建立」→「查詢設計」→ 關閉跳出的「新增資料表」對話框。
3. 工具列切換到 **「SQL 檢視」**。
4. 打開 `schema.sql`，**依 [1/6] → [6/6] 順序**，一次複製一個 `CREATE` 語句
   （不要複製 `--` 開頭的註解），貼上 → 按「執行 (!)」。
5. 六個資料表都建完後，執行一次插入初始資料：
   ```sql
   INSERT INTO SchemaInfo (SchemaVersion, AppliedAt) VALUES (1, Now());
   INSERT INTO Players (PlayerName, CreatedAt) VALUES ('Player1', Now());
   ```
6. 關閉 Access（確認資料夾裡的 `SudokuGame.laccdb` 鎖定檔消失），再跑 C# 程式。

---

## 4. 遊戲規則程式（`Sudoku.Core`）

這一層完全不碰資料庫，可以先寫完、先測完。

### 4.1 數獨基本規則

一個 9×9 盤面，分成 9 個 3×3 的「宮」。填入 1~9，且滿足：

1. 每一**列**的 9 格數字不重複
2. 每一**行**的 9 格數字不重複
3. 每一**宮**的 9 格數字不重複

格子索引換算（整份程式統一用這組公式）：

```csharp
int index = row * 9 + col;          // 0 ~ 80
int row   = index / 9;
int col   = index % 9;
int box   = (row / 3) * 3 + col / 3;  // 0 ~ 8
```

### 4.2 核心類別職責

| 類別 | 職責 | 關鍵成員 |
|---|---|---|
| `Cell` | 一格的狀態 | `Value`(0~9)、`IsGiven`(題目給定不可改)、`Candidates`(HashSet) |
| `Board` | 81 格的容器 | `this[int row, int col]`、`Clone()`、`IsFull` |
| `SudokuValidator` | 規則判斷（無狀態） | `CanPlace(board, index, value)`、`FindConflicts(board, index)`、`IsSolved(board)` |
| `SudokuSolver` | 求解 | `TrySolve(board, out solved)`、`CountSolutions(board, limit)` |
| `SudokuGenerator` | 出題 | `Generate(Difficulty) → (givens, solution)` |
| `BoardSerializer` | 字串轉換 | `ToString81(board)`、`Parse(string)` |
| `GameEngine` | 對外門面，管理一場遊戲 | `Place`、`Erase`、`ToggleNote`、`Undo`、`Redo`、`GetHint`、`Save` |

### 4.3 驗證邏輯

```
CanPlace(board, index, value):
    如果 board[index].IsGiven          → false（題目給定的格子不能改）
    對同列的其他 8 格，若有人 == value  → false
    對同行的其他 8 格，若有人 == value  → false
    對同宮的其他 8 格，若有人 == value  → false
    否則 → true
```

**效能提示**：若覺得每次掃 27 格太慢，可在 `Board` 內維護
`rowMask[9]`、`colMask[9]`、`boxMask[9]` 三組 9 個 bit 的位元遮罩，
判斷變成 `(mask & (1 << value)) == 0`，是 O(1)。
求解器與產生器會做幾十萬次判斷，這個最佳化在 §4.5 很有感。

### 4.4 求解器（回溯法 + MRV）

```
TrySolve(board):
    找出「候選數最少」的那個空格          ← MRV，比從左上依序找快非常多
    若沒有空格 → 解出來了，回傳 true
    若該格候選數為 0 → 死路，回傳 false
    對每個候選數 v：
        填入 v
        遞迴 TrySolve
        成功 → 回傳 true
        失敗 → 還原成空格（回溯）
    回傳 false
```

`CountSolutions(board, limit)` 是同一套邏輯，但**不在找到第一組解時停止**，
而是繼續累加，直到數量達到 `limit`（產生題目時只需要 `limit = 2`，
因為我們只在乎「是不是剛好一組解」）。

### 4.5 題目產生器（挖洞法）

```
Generate(difficulty):
    步驟 1  在空盤上用「候選數隨機打亂」的回溯法填出一組完整合法解 → solution
    步驟 2  把 0~80 的格子索引隨機打亂成一個清單
    步驟 3  依序嘗試挖掉每一格：
              暫存原值 → 設為 0
              用 CountSolutions(board, 2) 檢查
              若解的數量 != 1 → 還原這一格（不能挖）
              若 == 1        → 挖成功，已挖數 +1
            直到「已挖數」達到該難度的目標，或清單走完
    步驟 4  回傳 (givens, solution)
```

**唯一解是數獨題目的必要條件**，步驟 3 的檢查絕對不能省。

難度對照（給定數字的個數）：

| 難度 | 保留的提示數 | 概略挖洞數 |
|---|---|---|
| Easy | 40 ~ 45 | 36 ~ 41 |
| Medium | 32 ~ 39 | 42 ~ 49 |
| Hard | 27 ~ 31 | 50 ~ 54 |
| Expert | 22 ~ 26 | 55 ~ 59 |

> 注意：低於 17 個提示的數獨題目**在數學上不可能有唯一解**，Expert 不要設太低。
> 另外「提示數少」不完全等於「難」，但對本專案而言這個近似已經夠用；
> 若日後想更精準，可改用「解這題需要用到哪些解題技巧」來評級。

### 4.6 遊戲操作（`GameEngine`）

| 操作 | 行為 |
|---|---|
| `Place(row, col, value)` | 檢查非 Given → 記錄 Move → 填入。若與 `Solution` 不符則 `MistakeCount++`（可設為 3 次上限） |
| `Erase(row, col)` | 清空該格（Given 不可清） |
| `ToggleNote(row, col, value)` | 在候選數集合中加入/移除 |
| `Undo()` / `Redo()` | 兩個 `Stack<Move>` 互推 |
| `GetHint()` | 從 `Solution` 挑一個空格填入，`HintUsedCount++` |
| `CheckWin()` | `board.IsFull && validator.IsSolved(board)` → 標記完成 |
| 計時 | `Stopwatch` 計時，存檔時累加進 `ElapsedSeconds` |

---

## 5. 資料庫連結程式（`Sudoku.Data`）

### 5.1 NuGet 套件

```xml
<PackageReference Include="System.Data.OleDb" Version="8.0.0" />
```

`.csproj` 設定：

```xml
<TargetFramework>net8.0-windows</TargetFramework>
<PlatformTarget>x64</PlatformTarget>   <!-- 依 §1.2 決定 x64 或 x86 -->
```

### 5.2 連線字串

放在 `appsettings.json`，不要寫死在程式裡：

```json
{
  "Database": {
    "FilePath": "data\\SudokuGame.accdb",
    "Provider": "Microsoft.ACE.OLEDB.12.0"
  }
}
```

組出來的連線字串：

```
Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\...\data\SudokuGame.accdb;Persist Security Info=False;
```

`AccessConnectionFactory` 負責：把相對路徑轉成絕對路徑、組字串、`CreateConnection()`。
若 ACE 12.0 註冊失敗，可 fallback 試 `Microsoft.ACE.OLEDB.16.0`。

### 5.3 啟動健康檢查（`DbHealthCheck`）

程式一啟動就檢查，錯誤訊息要能直接告訴使用者怎麼修：

| 檢查 | 失敗時的訊息 |
|---|---|
| `.accdb` 檔案存在？ | 「找不到資料庫，請依 docs/sudoku/schema.sql 建立」 |
| 能開啟連線？ | 「ACE 驅動未安裝或位元數不符，請見 §1.2」 |
| 六張表都在？ | 用 `connection.GetSchema("Tables")` 檢查，列出缺少的表 |
| `SchemaVersion` 相符？ | 「資料庫版本 N，程式需要版本 1」 |

### 5.4 Repository 介面（定義在 `Core/Abstractions`）

```csharp
public interface IGameSessionRepository
{
    int Create(int playerId, int puzzleId, string board, DateTime startedAt);
    GameSessionRecord? GetById(int sessionId);
    IReadOnlyList<SessionSummary> ListInProgress(int playerId);
    void Save(GameSessionRecord session);       // 對應 schema.sql 的 Q3
    void Complete(int sessionId, int elapsedSeconds);
    void AppendMoves(int sessionId, IEnumerable<Move> moves);
}
```

`Core` 只認識這個介面；`Data` 提供 `AccessGameSessionRepository` 實作。
單元測試可以塞一個記憶體版假實作，完全不需要 Access。

### 5.5 ADO.NET 撰寫守則

1. **一律用參數化查詢**，不要用字串串接組 SQL。
2. **參數順序 = SQL 中 `?` 的順序**（見 §3.5 第 4 點）。這是 OleDb 最容易出錯的地方。
3. `OleDbConnection` / `OleDbCommand` / `OleDbDataReader` 都用 `using` 包起來。
4. **短連線**：每個 Repository 方法自己開、自己關，不要抱著一條連線整場遊戲不放
   （會產生 `.laccdb` 鎖定檔，導致 Access 無法同時開啟該檔）。
5. **存檔用交易**：更新 `GameSessions` + 批次寫 `Moves` 必須在同一個
   `OleDbTransaction` 內，避免存檔存到一半。
6. 日期一律**用參數傳 `DateTime`**，不要自己組 `#2026/08/02#` 字串（區域設定會坑你）。

存檔的典型寫法：

```csharp
using var conn = _factory.CreateConnection();
conn.Open();
using var tx = conn.BeginTransaction();
try
{
    // 1) UPDATE GameSessions ...
    // 2) foreach 新增的 Move → INSERT INTO Moves ...
    tx.Commit();
}
catch
{
    tx.Rollback();
    throw;
}
```

### 5.6 存檔時機

| 時機 | 動作 |
|---|---|
| 開新局 | INSERT Puzzles（若是新題）+ INSERT GameSessions |
| 每 N 步（建議 N=10） | 自動存檔（Q3） |
| 玩家按 `save` | 立即存檔 |
| 離開遊戲 | 存檔後才返回主選單 |
| 完成 | Q4，狀態改 `Completed` |

---

## 6. 操作介面程式（`Sudoku.ConsoleApp`）

### 6.1 畫面流程

```
啟動
 └─► DbHealthCheck（失敗 → 顯示修復指引後結束）
      └─► 主選單
            ├─ 1. 開新遊戲 ─► 選難度 ─► 產生題目 ─► 遊戲主迴圈
            ├─ 2. 載入遊戲 ─► 列出 InProgress 存檔 ─► 選一個 ─► 遊戲主迴圈
            ├─ 3. 查看統計 ─► 統計畫面 ─► 返回
            └─ 4. 離開
```

### 6.2 盤面畫面（`BoardRenderer`）

```
        1  2  3   4  5  6   7  8  9
      ╔═════════╦═════════╦═════════╗
   A  ║ 5  3  · ║ ·  7  · ║ ·  ·  · ║
   B  ║ 6  ·  · ║ 1  9  5 ║ ·  ·  · ║
   C  ║ ·  9  8 ║ ·  ·  · ║ ·  6  · ║
      ╠═════════╬═════════╬═════════╣
   D  ║ 8  ·  · ║ ·  6  · ║ ·  ·  3 ║
   E  ║ 4  ·  · ║ 8  ·  3 ║ ·  ·  1 ║
   F  ║ 7  ·  · ║ ·  2  · ║ ·  ·  6 ║
      ╠═════════╬═════════╬═════════╣
   G  ║ ·  6  · ║ ·  ·  · ║ 2  8  · ║
   H  ║ ·  ·  · ║ 4  1  9 ║ ·  ·  5 ║
   I  ║ ·  ·  · ║ ·  8  · ║ ·  7  9 ║
      ╚═════════╩═════════╩═════════╝

  難度：Medium    時間：08:42    提示：1    錯誤：0/3

  > _
```

- 列用 `A`~`I`、行用 `1`~`9`，比「第幾列第幾行」好唸也好輸入。
- 空格用 `·`（比空白更容易對齊視線）。
- 顏色（`Console.ForegroundColor`）：
  題目給定＝白色、玩家填入＝青色、衝突格＝紅色、剛提示的格＝黃色。
  顏色是加分項，第一版可以先不做。

### 6.3 指令設計（`CommandParser`）

主控台版採**打字下指令**，比方向鍵移動游標好寫、好測試：

| 指令 | 說明 |
|---|---|
| `a1 5` 或 `a1=5` | 在 A1 格填入 5 |
| `a1 0` 或 `d a1` | 清除 A1 格 |
| `n a1 125` | 在 A1 標註候選數 1、2、5（再輸入一次同樣的數字＝取消） |
| `u` / `r` | 復原 / 重做 |
| `h` | 提示（自動填一格） |
| `c` | 檢查目前盤面有沒有錯 |
| `s` | 立即存檔 |
| `q` | 存檔並回主選單 |
| `?` | 顯示指令說明 |

解析規則：全部轉小寫、去空白；用一個 regex 認 `^([a-i])([1-9])\s*=?\s*([0-9])$` 之類的格式。
無法解析時，印出提示而不是丟例外——這是主控台程式最重要的體驗細節。

### 6.4 遊戲主迴圈（`GameLoop`）

```
載入或建立 GameSession
啟動 Stopwatch
迴圈：
    清畫面 → 畫盤面 → 畫狀態列 → 讀取一行輸入
    解析指令
        失敗      → 顯示錯誤訊息，continue
        成功      → 交給 GameEngine 執行
    每 10 步或收到 save → 呼叫 repository.Save()
    若 engine.CheckWin() → 顯示恭喜畫面 + 用時 → Complete() → break
    若 MistakeCount >= 3 → 顯示失敗 → 詢問是否繼續
```

**注意**：不要在每一次按鍵都寫資料庫，Access 的寫入延遲會讓遊戲很卡（見 §3.4）。

---

## 7. 開發階段與里程碑

每個階段結束都應該 **commit**，且 M1~M2 完全不需要資料庫。

| 階段 | 內容 | 完成標準 |
|---|---|---|
| **M0** | 建 solution 與四個專案、裝 NuGet、確認 §1.2 位元數 | `dotnet build` 成功 |
| **M1** | `Cell` / `Board` / `SudokuValidator` / `BoardSerializer` | 單元測試：合法盤面通過、每種衝突都被抓出、字串來回轉換不失真 |
| **M2** | `SudokuSolver` / `SudokuGenerator` | 測試：能解出已知題目；產生 100 題，每題都是唯一解且提示數符合難度 |
| **M3** | 依 §3.6 在 Access 建好 6 張表；`AccessConnectionFactory` + `DbHealthCheck` | 一支小程式能連上 DB 並列出資料表名稱 |
| **M4** | 三個 Repository 的實作 | 能新增玩家 / 存入題目 / 建立存檔 / 讀回存檔，資料在 Access 裡看得到 |
| **M5** | `BoardRenderer` + `CommandParser` + `GameLoop`（先用記憶體假 Repository） | 能完整玩完一局，不碰資料庫 |
| **M6** | 串接：`Program.cs` 注入 Access Repository、自動存檔、載入遊戲 | 玩到一半關掉，重開能接續 |
| **M7** | 統計畫面、提示、錯誤上限、顏色、`?` 說明 | 體驗打磨完成 |

### 建議的最小可玩版本（MVP）

**M0 → M1 → M2 → M5**（用記憶體 Repository）就能玩了。
資料庫（M3、M4、M6）可以在「確定遊戲好玩」之後再接上去。
這樣做的好處是：即使 ACE 驅動裝了半天裝不起來，遊戲本體的進度也不會被卡住。

---

## 8. 測試計畫

| 測試對象 | 重點案例 |
|---|---|
| `SudokuValidator` | 同列重複、同行重複、同宮重複、Given 不可改、合法填入 |
| `BoardSerializer` | 81 字元來回轉換一致；長度不足 / 含非法字元要丟例外 |
| `SudokuSolver` | 已知題目解得出且與標準答案相同；無解盤面回傳 false；多解盤面 `CountSolutions` 回傳 ≥ 2 |
| `SudokuGenerator` | 產生 100 題：每題唯一解、提示數落在難度區間、`Solution` 本身合法 |
| `GameEngine` | Undo 後盤面回到上一步；Redo 還原；提示填的值必等於 Solution |
| Repository（整合測試） | 用一份測試專用的 `.accdb` 複本；存檔後讀回，欄位完全相同；交易失敗會 rollback |

Repository 整合測試只能在 Windows 跑，記得加上 `[Trait("Category","Windows")]` 之類的標記，
才不會在別的環境誤觸發。

---

## 9. 風險與注意事項

| 風險 | 影響 | 對策 |
|---|---|---|
| ACE 驅動未安裝 / 位元數不符 | 程式完全連不上 DB | §1.2；`DbHealthCheck` 給出明確修復指引 |
| `.laccdb` 鎖定檔殘留 | Access 與程式互相卡住 | 短連線（§5.5 第 4 點）；程式結束前確保連線都關了 |
| 產生 Expert 難度題目太慢 | 開新局要等好幾秒 | 位元遮罩最佳化（§4.3）；或預先產生一批題目存進 `Puzzles` 表當題庫 |
| Access 檔案損毀 | 存檔全失 | 定期用 Access 的「壓縮與修復」；每次啟動時複製一份 `.accdb.bak` |
| `.accdb` 被 commit 進 git | 二進位檔膨脹 repo | 加進 `.gitignore`（本次已一併處理） |
| OleDb 參數順序寫錯 | 資料錯亂但不報錯 | Repository 每個方法都寫整合測試；SQL 與參數加入順序寫在同一段程式碼裡好對照 |

---

## 10. 後續可擴充方向

- **解題技巧提示**：不只填答案，而是提示「這裡可以用 Naked Single / Hidden Single」。
- **難度重新評級**：用求解時需要的技巧層級取代「提示數」來定難度。
- **題庫預載**：背景預先產生題目存進 `Puzzles`，開新局不用等。
- **換 GUI**：`Sudoku.Core` 完全不用動，加一個 `Sudoku.WinForms` 專案即可。
- **換資料庫**：實作一組 `Sqlite*Repository`，程式就跨平台了，`Core` 一行不用改。

---

## 附錄：相關檔案

| 檔案 | 內容 |
|---|---|
| [`schema.sql`](./schema.sql) | 完整 Access DDL + 常用查詢，可直接貼進 Access 執行 |
