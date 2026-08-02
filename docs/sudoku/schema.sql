-- =====================================================================
-- 數獨遊戲 Access 資料庫 DDL  (SudokuGame.accdb)
--
-- ！！使用前必讀！！
--   1. Access 的「查詢 → SQL 檢視」不支援 SQL 註解（-- 或 /* */），
--      也不支援一次執行多句。請「一次只複製一個 CREATE 語句」
--      （不要複製 -- 開頭的註解行），貼上後按「執行」。
--   2. 請「完全依照下面的順序」建立，因為外鍵會參照前面的資料表。
--   3. Access SQL DDL 不支援 DEFAULT 與 CHECK 條件約束（在 UI 的
--      ANSI-89 模式下），這些規則一律由 C# 應用程式層負責把關。
--      若要在欄位上設預設值，請建完表後到「設計檢視」手動填。
--   4. 建立步驟：Access →「建立」→「查詢設計」→ 關閉「新增資料表」
--      → 工具列切到「SQL 檢視」→ 貼上 → 執行(!) → 重複下一句。
--
-- 型別對照（Access DDL）
--   AUTOINCREMENT ... 自動編號（Long）
--   INTEGER       ... Long Integer（4 bytes，-2^31 ~ 2^31-1）
--   SMALLINT      ... Integer（2 bytes）
--   BYTE          ... 位元組（0~255）
--   TEXT(n)       ... 簡短文字，n <= 255
--   LONGTEXT      ... 長文字 / MEMO
--   DATETIME      ... 日期/時間
--   YESNO         ... 是/否（布林）
-- =====================================================================


-- ---------------------------------------------------------------------
-- [1/6] SchemaInfo：結構版本，供未來做資料庫升級判斷
--       建表後請手動或由程式插入一筆 SchemaVersion = 1
-- ---------------------------------------------------------------------
CREATE TABLE SchemaInfo (
    SchemaVersion  INTEGER  NOT NULL,
    AppliedAt      DATETIME NOT NULL,
    CONSTRAINT PK_SchemaInfo PRIMARY KEY (SchemaVersion)
);


-- ---------------------------------------------------------------------
-- [2/6] Players：玩家（本機單機用，可只有一位玩家）
-- ---------------------------------------------------------------------
CREATE TABLE Players (
    PlayerId    AUTOINCREMENT NOT NULL,
    PlayerName  TEXT(50)      NOT NULL,
    CreatedAt   DATETIME      NOT NULL,
    CONSTRAINT PK_Players PRIMARY KEY (PlayerId),
    CONSTRAINT UQ_Players_Name UNIQUE (PlayerName)
);


-- ---------------------------------------------------------------------
-- [3/6] Puzzles：題目庫。Givens / Solution 皆為 81 字元字串
--       （由左上到右下逐列展開，'1'~'9' 表示數字，'0' 表示空格）
--       Difficulty：Easy / Medium / Hard / Expert
--       PuzzleCode：GUID 字串，用來避免重複產生同一題
-- ---------------------------------------------------------------------
CREATE TABLE Puzzles (
    PuzzleId     AUTOINCREMENT NOT NULL,
    PuzzleCode   TEXT(36)      NOT NULL,
    Givens       TEXT(81)      NOT NULL,
    Solution     TEXT(81)      NOT NULL,
    Difficulty   TEXT(10)      NOT NULL,
    GivenCount   BYTE          NOT NULL,
    PuzzleSource TEXT(20)      NOT NULL,
    CreatedAt    DATETIME      NOT NULL,
    CONSTRAINT PK_Puzzles PRIMARY KEY (PuzzleId),
    CONSTRAINT UQ_Puzzles_Code UNIQUE (PuzzleCode)
);

CREATE INDEX IX_Puzzles_Difficulty ON Puzzles (Difficulty);


-- ---------------------------------------------------------------------
-- [4/6] GameSessions：一場遊戲的存檔（核心資料表）
--       CurrentBoard：目前盤面 81 字元字串
--       NotesJson   ：候選數筆記，JSON 字串，例如
--                     {"0":[1,2,5],"34":[7,9]}  （key = 0~80 的格子索引）
--       SessionStatus：InProgress / Completed / Abandoned
-- ---------------------------------------------------------------------
CREATE TABLE GameSessions (
    SessionId       AUTOINCREMENT NOT NULL,
    PlayerId        INTEGER       NOT NULL,
    PuzzleId        INTEGER       NOT NULL,
    CurrentBoard    TEXT(81)      NOT NULL,
    NotesJson       LONGTEXT,
    ElapsedSeconds  INTEGER       NOT NULL,
    HintUsedCount   SMALLINT      NOT NULL,
    MistakeCount    SMALLINT      NOT NULL,
    SessionStatus   TEXT(12)      NOT NULL,
    StartedAt       DATETIME      NOT NULL,
    LastSavedAt     DATETIME      NOT NULL,
    CompletedAt     DATETIME,
    CONSTRAINT PK_GameSessions PRIMARY KEY (SessionId),
    CONSTRAINT FK_Sessions_Player  FOREIGN KEY (PlayerId) REFERENCES Players (PlayerId),
    CONSTRAINT FK_Sessions_Puzzle  FOREIGN KEY (PuzzleId) REFERENCES Puzzles (PuzzleId)
);

CREATE INDEX IX_Sessions_Player ON GameSessions (PlayerId, SessionStatus);


-- ---------------------------------------------------------------------
-- [5/6] Moves：每一步的操作紀錄，供「復原 / 重做」與行為統計使用
--       MoveKind：SetValue / Erase / Note / Hint
--       CellIndex：0~80（= RowIndex * 9 + ColIndex）
--       OldValue / NewValue：0~9，0 代表空白
-- ---------------------------------------------------------------------
CREATE TABLE Moves (
    MoveId     AUTOINCREMENT NOT NULL,
    SessionId  INTEGER       NOT NULL,
    MoveNo     INTEGER       NOT NULL,
    CellIndex  BYTE          NOT NULL,
    OldValue   BYTE          NOT NULL,
    NewValue   BYTE          NOT NULL,
    MoveKind   TEXT(10)      NOT NULL,
    IsMistake  YESNO         NOT NULL,
    CreatedAt  DATETIME      NOT NULL,
    CONSTRAINT PK_Moves PRIMARY KEY (MoveId),
    CONSTRAINT FK_Moves_Session FOREIGN KEY (SessionId) REFERENCES GameSessions (SessionId)
);

CREATE INDEX IX_Moves_Session ON Moves (SessionId, MoveNo);


-- ---------------------------------------------------------------------
-- [6/6] PlayerStats：可選。若嫌每次統計都掃描 GameSessions 太慢，
--       可用這張表做快取（每完成一局更新一次）。
--       初期建議先不要建，直接用下方的統計查詢即可。
-- ---------------------------------------------------------------------
CREATE TABLE PlayerStats (
    PlayerId       INTEGER  NOT NULL,
    Difficulty     TEXT(10) NOT NULL,
    PlayedCount    INTEGER  NOT NULL,
    ClearedCount   INTEGER  NOT NULL,
    BestSeconds    INTEGER,
    TotalSeconds   INTEGER  NOT NULL,
    UpdatedAt      DATETIME NOT NULL,
    CONSTRAINT PK_PlayerStats PRIMARY KEY (PlayerId, Difficulty),
    CONSTRAINT FK_Stats_Player FOREIGN KEY (PlayerId) REFERENCES Players (PlayerId)
);


-- =====================================================================
-- 常用查詢（可存成 Access 查詢，或直接寫在 C# 的 Repository 裡）
-- 注意：OleDb 的參數是「位置式」的問號 ?，順序必須與 SQL 中出現的
--       順序完全一致，參數名稱會被忽略。
-- =====================================================================

-- Q1. 讀取某玩家所有「進行中」的存檔（載入遊戲清單）
SELECT s.SessionId, p.Difficulty, s.ElapsedSeconds, s.LastSavedAt
FROM GameSessions AS s INNER JOIN Puzzles AS p ON s.PuzzleId = p.PuzzleId
WHERE s.PlayerId = ? AND s.SessionStatus = 'InProgress'
ORDER BY s.LastSavedAt DESC;

-- Q2. 讀取單一存檔的完整內容（含題目與解答）
SELECT s.SessionId, s.CurrentBoard, s.NotesJson, s.ElapsedSeconds,
       s.HintUsedCount, s.MistakeCount, s.StartedAt,
       p.PuzzleId, p.Givens, p.Solution, p.Difficulty
FROM GameSessions AS s INNER JOIN Puzzles AS p ON s.PuzzleId = p.PuzzleId
WHERE s.SessionId = ?;

-- Q3. 存檔（每次自動存檔 / 手動存檔都呼叫這句）
UPDATE GameSessions
SET CurrentBoard = ?, NotesJson = ?, ElapsedSeconds = ?,
    HintUsedCount = ?, MistakeCount = ?, LastSavedAt = ?
WHERE SessionId = ?;

-- Q4. 完成一局
UPDATE GameSessions
SET CurrentBoard = ?, ElapsedSeconds = ?, SessionStatus = 'Completed',
    CompletedAt = ?, LastSavedAt = ?
WHERE SessionId = ?;

-- Q5. 統計：各難度的完成局數與最佳時間
SELECT p.Difficulty,
       COUNT(*) AS ClearedCount,
       MIN(s.ElapsedSeconds) AS BestSeconds,
       AVG(s.ElapsedSeconds) AS AvgSeconds
FROM GameSessions AS s INNER JOIN Puzzles AS p ON s.PuzzleId = p.PuzzleId
WHERE s.PlayerId = ? AND s.SessionStatus = 'Completed'
GROUP BY p.Difficulty;

-- Q6. 取得剛新增的自動編號（必須用「同一個已開啟的 OleDbConnection」執行）
SELECT @@IDENTITY;
