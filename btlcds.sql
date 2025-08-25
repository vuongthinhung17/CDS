/* ===== 0) CREATE / USE DATABASE ===== */
IF DB_ID(N'TravelChatDB') IS NULL
BEGIN
  CREATE DATABASE TravelChatDB;
END
GO
USE TravelChatDB;
GO

/* ===== 1) DROP TRIGGER (nếu có) ===== */
IF OBJECT_ID('dbo.tr_Itineraries_SetNull_Bookings','TR') IS NOT NULL
  DROP TRIGGER dbo.tr_Itineraries_SetNull_Bookings;
GO


/* ===== 2) DROP TABLES (ngược phụ thuộc) ===== */
IF OBJECT_ID('dbo.Feedbacks','U')  IS NOT NULL DROP TABLE dbo.Feedbacks;
IF OBJECT_ID('dbo.Bookings','U')   IS NOT NULL DROP TABLE dbo.Bookings;
IF OBJECT_ID('dbo.Activities','U') IS NOT NULL DROP TABLE dbo.Activities;
IF OBJECT_ID('dbo.ItineraryDays','U') IS NOT NULL DROP TABLE dbo.ItineraryDays;
IF OBJECT_ID('dbo.Itineraries','U') IS NOT NULL DROP TABLE dbo.Itineraries;
IF OBJECT_ID('dbo.Messages','U')   IS NOT NULL DROP TABLE dbo.Messages;
IF OBJECT_ID('dbo.ModelCalls','U') IS NOT NULL DROP TABLE dbo.ModelCalls;
IF OBJECT_ID('dbo.Sessions','U')   IS NOT NULL DROP TABLE dbo.Sessions;
IF OBJECT_ID('dbo.Providers','U')  IS NOT NULL DROP TABLE dbo.Providers;
IF OBJECT_ID('dbo.Locations','U')  IS NOT NULL DROP TABLE dbo.Locations;
IF OBJECT_ID('dbo.Users','U')      IS NOT NULL DROP TABLE dbo.Users;
GO

/* ===== 3) CORE ENTITIES ===== */
CREATE TABLE dbo.Users(
  user_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Users PRIMARY KEY
    CONSTRAINT DF_Users_Id DEFAULT NEWSEQUENTIALID(),
  email NVARCHAR(320) NOT NULL
    CONSTRAINT UQ_Users_Email UNIQUE,
  display_name NVARCHAR(100) NULL,
  [role] NVARCHAR(20) NOT NULL
    CONSTRAINT DF_Users_Role DEFAULT N'user',
  created_at DATETIME2(7) NOT NULL
    CONSTRAINT DF_Users_Created DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.Sessions(
  session_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Sessions PRIMARY KEY
    CONSTRAINT DF_Sessions_Id DEFAULT NEWSEQUENTIALID(),
  user_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT FK_Sessions_Users
      FOREIGN KEY REFERENCES dbo.Users(user_id) ON DELETE CASCADE,
  title NVARCHAR(200) NULL,
  started_at DATETIME2(7) NOT NULL
    CONSTRAINT DF_Sessions_Started DEFAULT SYSUTCDATETIME(),
  [status] NVARCHAR(20) NULL
);
GO

CREATE TABLE dbo.ModelCalls(
  model_call_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_ModelCalls PRIMARY KEY
    CONSTRAINT DF_ModelCalls_Id DEFAULT NEWSEQUENTIALID(),
  provider NVARCHAR(50) NULL,
  model_name NVARCHAR(100) NULL,
  prompt NVARCHAR(MAX) NULL,
  temperature DECIMAL(4,2) NULL,
  latency_ms INT NULL,
  success BIT NULL,
  error_code NVARCHAR(100) NULL,
  created_at DATETIME2(7) NOT NULL
    CONSTRAINT DF_ModelCalls_Created DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.Messages(
  message_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Messages PRIMARY KEY
    CONSTRAINT DF_Messages_Id DEFAULT NEWSEQUENTIALID(),
  session_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT FK_Messages_Sessions
      FOREIGN KEY REFERENCES dbo.Sessions(session_id) ON DELETE CASCADE,
  sender NVARCHAR(10) NOT NULL
    CONSTRAINT CK_Messages_Sender CHECK (sender IN (N'user', N'assistant')),
  content NVARCHAR(MAX) NOT NULL,
  tokens_in INT NULL,
  tokens_out INT NULL,
  created_at DATETIME2(7) NOT NULL
    CONSTRAINT DF_Messages_Created DEFAULT SYSUTCDATETIME(),
  model_call_id UNIQUEIDENTIFIER NULL
    CONSTRAINT FK_Messages_ModelCalls
      FOREIGN KEY REFERENCES dbo.ModelCalls(model_call_id)
);
GO

/* ===== 4) ITINERARY & RELATED ===== */
CREATE TABLE dbo.Itineraries(
  itinerary_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Itineraries PRIMARY KEY
    CONSTRAINT DF_Itineraries_Id DEFAULT NEWSEQUENTIALID(),
  session_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT FK_Itineraries_Sessions
      FOREIGN KEY REFERENCES dbo.Sessions(session_id) ON DELETE CASCADE,
  title NVARCHAR(200) NULL,
  currency NVARCHAR(10) NULL,
  total_budget DECIMAL(18,2) NULL,
  days_count INT NULL,
  created_at DATETIME2(7) NOT NULL
    CONSTRAINT DF_Itineraries_Created DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.ItineraryDays(
  day_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_ItineraryDays PRIMARY KEY
    CONSTRAINT DF_ItineraryDays_Id DEFAULT NEWSEQUENTIALID(),
  itinerary_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT FK_ItineraryDays_Itineraries
      FOREIGN KEY REFERENCES dbo.Itineraries(itinerary_id) ON DELETE CASCADE,
  day_no INT NOT NULL,
  [date] DATE NULL,
  notes NVARCHAR(MAX) NULL,
  CONSTRAINT UQ_ItineraryDays_Itinerary_DayNo UNIQUE (itinerary_id, day_no)
);
GO

CREATE TABLE dbo.Locations(
  location_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Locations PRIMARY KEY
    CONSTRAINT DF_Locations_Id DEFAULT NEWSEQUENTIALID(),
  [name] NVARCHAR(200) NOT NULL,
  [address] NVARCHAR(400) NULL,
  lat DECIMAL(9,6) NULL,
  lng DECIMAL(9,6) NULL,
  place_id NVARCHAR(100) NULL
);
GO

CREATE TABLE dbo.Activities(
  activity_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Activities PRIMARY KEY
    CONSTRAINT DF_Activities_Id DEFAULT NEWSEQUENTIALID(),
  day_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT FK_Activities_ItineraryDays
      FOREIGN KEY REFERENCES dbo.ItineraryDays(day_id) ON DELETE CASCADE,
  start_time TIME NULL,
  end_time TIME NULL,
  category NVARCHAR(50) NULL,
  [title] NVARCHAR(200) NOT NULL,
  location_id UNIQUEIDENTIFIER NULL
    CONSTRAINT FK_Activities_Locations
      FOREIGN KEY REFERENCES dbo.Locations(location_id) ON DELETE SET NULL,
  cost DECIMAL(18,2) NULL
);
GO

/* ===== 5) PROVIDERS & BOOKINGS (đã xử lý cascade) ===== */
CREATE TABLE dbo.Providers(
  provider_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Providers PRIMARY KEY
    CONSTRAINT DF_Providers_Id DEFAULT NEWSEQUENTIALID(),
  [name] NVARCHAR(200) NOT NULL,
  [type] NVARCHAR(50) NULL,
  url NVARCHAR(400) NULL
);
GO

CREATE TABLE dbo.Bookings(
  booking_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Bookings PRIMARY KEY
    CONSTRAINT DF_Bookings_Id DEFAULT NEWSEQUENTIALID(),
  itinerary_id UNIQUEIDENTIFIER NULL
    CONSTRAINT FK_Bookings_Itineraries
      FOREIGN KEY (itinerary_id) REFERENCES dbo.Itineraries(itinerary_id),   -- NO ACTION
  activity_id UNIQUEIDENTIFIER NULL
    CONSTRAINT FK_Bookings_Activities
      FOREIGN KEY (activity_id)  REFERENCES dbo.Activities(activity_id) ON DELETE SET NULL,
  provider_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT FK_Bookings_Providers
      FOREIGN KEY REFERENCES dbo.Providers(provider_id),
  [type] NVARCHAR(30) NULL,
  [reference] NVARCHAR(100) NULL,
  [status] NVARCHAR(30) NULL,
  price DECIMAL(18,2) NULL,
  currency NVARCHAR(10) NULL
);
GO

/* ===== 6) FEEDBACKS (itinerary FK NO ACTION) ===== */
CREATE TABLE dbo.Feedbacks(
  feedback_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT PK_Feedbacks PRIMARY KEY
    CONSTRAINT DF_Feedbacks_Id DEFAULT NEWSEQUENTIALID(),
  user_id UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT FK_Feedbacks_Users
      FOREIGN KEY REFERENCES dbo.Users(user_id) ON DELETE CASCADE,
  message_id UNIQUEIDENTIFIER NULL
    CONSTRAINT FK_Feedbacks_Messages
      FOREIGN KEY REFERENCES dbo.Messages(message_id) ON DELETE CASCADE,
  itinerary_id UNIQUEIDENTIFIER NULL
    CONSTRAINT FK_Feedbacks_Itineraries
      FOREIGN KEY REFERENCES dbo.Itineraries(itinerary_id),  -- NO ACTION
  rating INT NOT NULL
    CONSTRAINT CK_Feedbacks_Rating CHECK (rating BETWEEN 1 AND 5),
  comment NVARCHAR(MAX) NULL,
  created_at DATETIME2(7) NOT NULL
    CONSTRAINT DF_Feedbacks_Created DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_Feedbacks_Target CHECK (message_id IS NOT NULL OR itinerary_id IS NOT NULL)
);
GO


-- **) Bỏ FK cũ (nếu có) rồi tạo lại mà KHÔNG CASCADE
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Feedbacks_Users')
BEGIN
  ALTER TABLE dbo.Feedbacks DROP CONSTRAINT FK_Feedbacks_Users;
END
GO

ALTER TABLE dbo.Feedbacks WITH CHECK
ADD CONSTRAINT FK_Feedbacks_Users
FOREIGN KEY (user_id)
REFERENCES dbo.Users(user_id);   -- NO ACTION (mặc định)
GO

/* ===== 7) INDEXES ===== */
CREATE INDEX IX_Sessions_User             ON dbo.Sessions(user_id, started_at DESC);
CREATE INDEX IX_Messages_SessionTime      ON dbo.Messages(session_id, created_at);
CREATE INDEX IX_Itineraries_Session       ON dbo.Itineraries(session_id);
CREATE INDEX IX_ItineraryDays_Itin_DayNo  ON dbo.ItineraryDays(itinerary_id, day_no);
CREATE INDEX IX_Activities_Day            ON dbo.Activities(day_id);
CREATE INDEX IX_Bookings_Provider         ON dbo.Bookings(provider_id);
GO

/* ===== 8) TRIGGER: tự SET NULL itinerary_id trong Bookings khi xoá Itinerary ===== */
CREATE TRIGGER dbo.tr_Itineraries_SetNull_Bookings
ON dbo.Itineraries
AFTER DELETE
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE b
    SET b.itinerary_id = NULL
  FROM dbo.Bookings AS b
  INNER JOIN deleted AS d
    ON b.itinerary_id = d.itinerary_id;
END
GO

/* ===== 9) (Tùy chọn) CLEANUP orphan cũ nếu có =====
UPDATE b SET itinerary_id = NULL
FROM dbo.Bookings b
WHERE b.itinerary_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Itineraries i WHERE i.itinerary_id = b.itinerary_id);

UPDATE b SET activity_id = NULL
FROM dbo.Bookings b
WHERE b.activity_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Activities a WHERE a.activity_id = b.activity_id);
-- ============================================================================ */
