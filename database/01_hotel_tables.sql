/* =====================================================================
   01_hotel_tables.sql  -  Phụ trách: T (Leader + Database)
   DBMS : Microsoft SQL Server (T-SQL)
   Nội dung: tạo database + 6 bảng khách sạn (có NHAN_VIEN)
     1. NHAN_VIEN         (tài khoản đăng nhập + vai trò)
     2. KHACH_HANG
     3. LOAI_PHONG
     4. PHONG
     5. DAT_PHONG         (đặt theo LOẠI phòng, chưa gán số phòng)
     6. PHIEU_THUE_PHONG  (lúc nhận phòng mới gán số phòng cụ thể)
   Quy ước trạng thái (chuỗi phải GIỮ NGUYÊN ở backend/frontend):
     PHONG            : N'Trống' | N'Đang thuê' | N'Bảo trì'
     DAT_PHONG        : N'Đã đặt' | N'Đã nhận' | N'Đã hủy'
     PHIEU_THUE_PHONG : N'Đang thuê' | N'Đã trả'
   Chạy lần đầu trên server sạch. Chạy lại: chạy 00_reset_database.sql trước.
   ===================================================================== */

IF DB_ID(N'QL_KhachSan_NhaHang') IS NULL
    CREATE DATABASE QL_KhachSan_NhaHang COLLATE Vietnamese_CI_AS;
GO
USE QL_KhachSan_NhaHang;
GO

/* ---------------------------------------------------------------------
   1. NHAN_VIEN
   MatKhauHash: lưu mã băm (bcrypt) do backend tạo, KHÔNG lưu mật khẩu thô.
   --------------------------------------------------------------------- */
CREATE TABLE NHAN_VIEN (
    MaNV         INT IDENTITY(1,1) NOT NULL,
    HoTen        NVARCHAR(100)     NOT NULL,
    TenDangNhap  VARCHAR(50)       NOT NULL,
    MatKhauHash  VARCHAR(255)      NOT NULL,
    VaiTro       NVARCHAR(20)      NOT NULL,
    SDT          VARCHAR(11)       NULL,
    TrangThai    BIT               NOT NULL CONSTRAINT DF_NV_TrangThai DEFAULT 1,  -- 1: đang làm, 0: nghỉ
    CONSTRAINT PK_NHAN_VIEN        PRIMARY KEY (MaNV),
    CONSTRAINT UQ_NV_TenDangNhap   UNIQUE (TenDangNhap),
    CONSTRAINT CK_NV_HoTen         CHECK (LEN(LTRIM(RTRIM(HoTen))) > 0),
    CONSTRAINT CK_NV_VaiTro        CHECK (VaiTro IN (N'Quản lý', N'Lễ tân', N'Bếp')),
    CONSTRAINT CK_NV_SDT           CHECK (SDT IS NULL
                                          OR (SDT NOT LIKE '%[^0-9]%' AND LEN(SDT) BETWEEN 10 AND 11))
);
GO

/* ---------------------------------------------------------------------
   2. KHACH_HANG
   CCCD: 12 số (CMND cũ 9 số vẫn chấp nhận). SDT: 10-11 số, bắt đầu bằng 0.
   --------------------------------------------------------------------- */
CREATE TABLE KHACH_HANG (
    MaKH     INT IDENTITY(1,1) NOT NULL,
    HoTen    NVARCHAR(100)     NOT NULL,
    CCCD     VARCHAR(12)       NOT NULL,
    SDT      VARCHAR(11)       NOT NULL,
    Email    VARCHAR(100)      NULL,
    DiaChi   NVARCHAR(200)     NULL,
    NgayTao  DATETIME          NOT NULL CONSTRAINT DF_KH_NgayTao DEFAULT GETDATE(),
    CONSTRAINT PK_KHACH_HANG PRIMARY KEY (MaKH),
    CONSTRAINT UQ_KH_CCCD    UNIQUE (CCCD),
    CONSTRAINT CK_KH_HoTen   CHECK (LEN(LTRIM(RTRIM(HoTen))) > 0),
    CONSTRAINT CK_KH_CCCD    CHECK (CCCD NOT LIKE '%[^0-9]%' AND LEN(CCCD) IN (9, 12)),
    CONSTRAINT CK_KH_SDT     CHECK (SDT NOT LIKE '%[^0-9]%' AND LEN(SDT) BETWEEN 10 AND 11 AND SDT LIKE '0%'),
    CONSTRAINT CK_KH_Email   CHECK (Email IS NULL OR Email LIKE '%_@_%._%')
);
GO
CREATE INDEX IX_KH_SDT   ON KHACH_HANG (SDT);
CREATE INDEX IX_KH_HoTen ON KHACH_HANG (HoTen);
GO

/* ---------------------------------------------------------------------
   3. LOAI_PHONG
   --------------------------------------------------------------------- */
CREATE TABLE LOAI_PHONG (
    MaLoai        INT IDENTITY(1,1) NOT NULL,
    TenLoai       NVARCHAR(50)      NOT NULL,
    GiaMotDem     DECIMAL(12,0)     NOT NULL,
    SoNguoiToiDa  INT               NOT NULL,
    MoTa          NVARCHAR(200)     NULL,
    CONSTRAINT PK_LOAI_PHONG    PRIMARY KEY (MaLoai),
    CONSTRAINT UQ_LP_TenLoai    UNIQUE (TenLoai),
    CONSTRAINT CK_LP_Gia        CHECK (GiaMotDem > 0),
    CONSTRAINT CK_LP_SoNguoi    CHECK (SoNguoiToiDa > 0)
);
GO

/* ---------------------------------------------------------------------
   4. PHONG
   Chỉ có 3 trạng thái vì đặt phòng theo loại; phòng chỉ "Đang thuê"
   khi đã có phiếu thuê chưa trả.
   --------------------------------------------------------------------- */
CREATE TABLE PHONG (
    MaPhong    INT IDENTITY(1,1) NOT NULL,
    SoPhong    VARCHAR(10)       NOT NULL,
    MaLoai     INT               NOT NULL,
    Tang       INT               NOT NULL,
    TrangThai  NVARCHAR(20)      NOT NULL CONSTRAINT DF_PHONG_TrangThai DEFAULT N'Trống',
    CONSTRAINT PK_PHONG          PRIMARY KEY (MaPhong),
    CONSTRAINT UQ_PHONG_SoPhong  UNIQUE (SoPhong),
    CONSTRAINT FK_PHONG_LOAI     FOREIGN KEY (MaLoai) REFERENCES LOAI_PHONG (MaLoai),
    CONSTRAINT CK_PHONG_Tang     CHECK (Tang > 0),
    CONSTRAINT CK_PHONG_TT       CHECK (TrangThai IN (N'Trống', N'Đang thuê', N'Bảo trì'))
);
GO
CREATE INDEX IX_PHONG_MaLoai    ON PHONG (MaLoai);
CREATE INDEX IX_PHONG_TrangThai ON PHONG (TrangThai);
GO

/* ---------------------------------------------------------------------
   5. DAT_PHONG  (khách đặt trước một LOẠI phòng cho khoảng ngày)
   Ràng buộc "ngày nhận không ở quá khứ" do sp_DatPhong kiểm tra
   (không đặt trong CHECK vì dữ liệu lịch sử vẫn phải hợp lệ).
   --------------------------------------------------------------------- */
CREATE TABLE DAT_PHONG (
    MaDat      INT IDENTITY(1,1) NOT NULL,
    MaKH       INT               NOT NULL,
    MaLoai     INT               NOT NULL,
    NgayDat    DATETIME          NOT NULL CONSTRAINT DF_DP_NgayDat DEFAULT GETDATE(),
    NgayNhan   DATE              NOT NULL,
    NgayTra    DATE              NOT NULL,
    TrangThai  NVARCHAR(20)      NOT NULL CONSTRAINT DF_DP_TrangThai DEFAULT N'Đã đặt',
    CONSTRAINT PK_DAT_PHONG   PRIMARY KEY (MaDat),
    CONSTRAINT FK_DP_KH       FOREIGN KEY (MaKH)   REFERENCES KHACH_HANG (MaKH),
    CONSTRAINT FK_DP_LOAI     FOREIGN KEY (MaLoai) REFERENCES LOAI_PHONG (MaLoai),
    CONSTRAINT CK_DP_Ngay     CHECK (NgayTra > NgayNhan),
    CONSTRAINT CK_DP_TT       CHECK (TrangThai IN (N'Đã đặt', N'Đã nhận', N'Đã hủy'))
);
GO
CREATE INDEX IX_DP_MaKH      ON DAT_PHONG (MaKH);
-- phục vụ kiểm tra "còn phòng trống loại X trong khoảng ngày" của sp_DatPhong
CREATE INDEX IX_DP_Loai_Ngay ON DAT_PHONG (MaLoai, NgayNhan, NgayTra) INCLUDE (TrangThai);
GO

/* ---------------------------------------------------------------------
   6. PHIEU_THUE_PHONG  (nhận phòng thực tế)
   - MaDat UNIQUE      : mỗi đơn đặt chỉ nhận phòng 1 lần (quan hệ 1-1).
   - GiaThue           : chụp lại giá/đêm lúc nhận phòng, để sau này đổi giá
                         LOAI_PHONG không làm sai hóa đơn cũ.
   - CK_PTP_TrangThai  : TrangThai và NgayTraThucTe luôn khớp nhau.
   - UX_PTP_Phong_DangThue: 1 phòng không thể có 2 phiếu "Đang thuê" cùng lúc.
   --------------------------------------------------------------------- */
CREATE TABLE PHIEU_THUE_PHONG (
    MaPhieu         INT IDENTITY(1,1) NOT NULL,
    MaDat           INT               NOT NULL,
    MaPhong         INT               NOT NULL,
    NgayNhanThucTe  DATETIME          NOT NULL CONSTRAINT DF_PTP_NgayNhan DEFAULT GETDATE(),
    NgayTraThucTe   DATETIME          NULL,
    GiaThue         DECIMAL(12,0)     NOT NULL,
    TrangThai       NVARCHAR(20)      NOT NULL CONSTRAINT DF_PTP_TrangThai DEFAULT N'Đang thuê',
    CONSTRAINT PK_PHIEU_THUE_PHONG PRIMARY KEY (MaPhieu),
    CONSTRAINT UQ_PTP_MaDat        UNIQUE (MaDat),
    CONSTRAINT FK_PTP_DATPHONG     FOREIGN KEY (MaDat)   REFERENCES DAT_PHONG (MaDat),
    CONSTRAINT FK_PTP_PHONG        FOREIGN KEY (MaPhong) REFERENCES PHONG (MaPhong),
    CONSTRAINT CK_PTP_Gia          CHECK (GiaThue > 0),
    CONSTRAINT CK_PTP_Ngay         CHECK (NgayTraThucTe IS NULL OR NgayTraThucTe >= NgayNhanThucTe),
    CONSTRAINT CK_PTP_TrangThai    CHECK (
           (TrangThai = N'Đang thuê' AND NgayTraThucTe IS NULL)
        OR (TrangThai = N'Đã trả'    AND NgayTraThucTe IS NOT NULL))
);
GO
CREATE INDEX IX_PTP_MaPhong ON PHIEU_THUE_PHONG (MaPhong);
CREATE UNIQUE INDEX UX_PTP_Phong_DangThue
    ON PHIEU_THUE_PHONG (MaPhong) WHERE TrangThai = N'Đang thuê';
GO

PRINT N'>>> Đã tạo xong database QL_KhachSan_NhaHang và 6 bảng khách sạn.';
GO
