/* =====================================================================
   01b_hotel_sample_data.sql  -  Dữ liệu mẫu khách sạn (T)
   Chạy SAU 01_hotel_tables.sql và TRƯỚC 03_logic.sql (khi chưa có trigger),
   vì trạng thái phòng ở đây được đặt sẵn cho khớp với phiếu thuê.
   Dữ liệu hoàn toàn giả. Ngày giả định "hôm nay" ~ 04/11/2026.
   Ngày giờ dùng định dạng YYYYMMDD để không phụ thuộc cấu hình ngôn ngữ.
   Mật khẩu: xem README (cột MatKhauHash đang là CHO_BCRYPT, cần cập nhật).
   ===================================================================== */
USE QL_KhachSan_NhaHang;
GO

/* ---- NHAN_VIEN ---- */
SET IDENTITY_INSERT NHAN_VIEN ON;
INSERT INTO NHAN_VIEN (MaNV, HoTen, TenDangNhap, MatKhauHash, VaiTro, SDT, TrangThai) VALUES
 (1, N'Nguyễn Quốc Thắng', 'admin',   'CHO_BCRYPT', N'Quản lý', '0281234567', 1),
 (2, N'Lê Thị Hoa',        'letan1',  'CHO_BCRYPT', N'Lễ tân',  '0902000001', 1),
 (3, N'Trần Văn Minh',     'letan2',  'CHO_BCRYPT', N'Lễ tân',  '0902000002', 1),
 (4, N'Phạm Thị Lan',      'bep1',    'CHO_BCRYPT', N'Bếp',     '0902000003', 1);
SET IDENTITY_INSERT NHAN_VIEN OFF;
GO

/* ---- KHACH_HANG (8 khách, 1 khách dùng CMND 9 số) ---- */
SET IDENTITY_INSERT KHACH_HANG ON;
INSERT INTO KHACH_HANG (MaKH, HoTen, CCCD, SDT, Email, DiaChi) VALUES
 (1, N'Nguyễn Văn An',     '079201001234', '0901234567', 'an.nguyen@example.com',  N'12 Lê Lợi, Quận 1, TP. Hồ Chí Minh'),
 (2, N'Trần Thị Bình',     '079202005678', '0912345678', 'binh.tran@example.com',  N'45 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh'),
 (3, N'Lê Hoàng Cường',    '075203009012', '0923456789', NULL,                     N'88 Phạm Văn Thuận, Biên Hòa, Đồng Nai'),
 (4, N'Phạm Thu Dung',     '001204003456', '0934567890', 'dung.pham@example.com',  N'25 Hàng Bài, Hoàn Kiếm, Hà Nội'),
 (5, N'Võ Minh Em',        '048205007890', '0945678901', 'em.vo@example.com',      N'10 Bạch Đằng, Hải Châu, Đà Nẵng'),
 (6, N'Đặng Quốc Phong',   '092206001122', '0956789012', NULL,                     N'7 Hòa Bình, Ninh Kiều, Cần Thơ'),
 (7, N'Bùi Thanh Giang',   '031207003344', '0967890123', 'giang.bui@example.com',  N'33 Lạch Tray, Ngô Quyền, Hải Phòng'),
 (8, N'Hoàng Gia Huy',     '123456789',    '0978901234', 'huy.hoang@example.com',  N'5 Trần Phú, Nha Trang, Khánh Hòa');
SET IDENTITY_INSERT KHACH_HANG OFF;
GO

/* ---- LOAI_PHONG (5 loại) ---- */
SET IDENTITY_INSERT LOAI_PHONG ON;
INSERT INTO LOAI_PHONG (MaLoai, TenLoai, GiaMotDem, SoNguoiToiDa, MoTa) VALUES
 (1, N'Standard', 500000,  2, N'Phòng tiêu chuẩn, 1 giường đôi'),
 (2, N'Superior', 700000,  2, N'Phòng cao cấp, có ban công'),
 (3, N'Deluxe',   1000000, 3, N'Phòng rộng, view thành phố'),
 (4, N'Family',   1500000, 4, N'Phòng gia đình, 2 giường đôi'),
 (5, N'Suite',    2500000, 2, N'Phòng hạng sang, phòng khách riêng');
SET IDENTITY_INSERT LOAI_PHONG OFF;
GO

/* ---- PHONG (15 phòng; 4 đang thuê, 1 bảo trì, 10 trống) ---- */
SET IDENTITY_INSERT PHONG ON;
INSERT INTO PHONG (MaPhong, SoPhong, MaLoai, Tang, TrangThai) VALUES
 (1,  '101', 1, 1, N'Trống'),
 (2,  '102', 1, 1, N'Đang thuê'),   -- phiếu 7
 (3,  '103', 2, 1, N'Trống'),
 (4,  '104', 2, 1, N'Trống'),
 (5,  '105', 3, 1, N'Đang thuê'),   -- phiếu 3
 (6,  '201', 1, 2, N'Trống'),
 (7,  '202', 2, 2, N'Trống'),
 (8,  '203', 2, 2, N'Trống'),
 (9,  '204', 3, 2, N'Bảo trì'),
 (10, '205', 3, 2, N'Trống'),
 (11, '301', 3, 3, N'Trống'),
 (12, '302', 4, 3, N'Đang thuê'),   -- phiếu 4
 (13, '303', 4, 3, N'Trống'),
 (14, '304', 4, 3, N'Trống'),
 (15, '305', 5, 3, N'Đang thuê');   -- phiếu 5
SET IDENTITY_INSERT PHONG OFF;
GO

/* ---- DAT_PHONG (10 đơn: 7 đã nhận, 2 sắp tới, 1 đã hủy) ---- */
SET IDENTITY_INSERT DAT_PHONG ON;
INSERT INTO DAT_PHONG (MaDat, MaKH, MaLoai, NgayDat, NgayNhan, NgayTra, TrangThai) VALUES
 (1,  1, 1, '20261015 09:00:00', '20261020', '20261023', N'Đã nhận'),
 (2,  2, 2, '20261020 10:30:00', '20261025', '20261028', N'Đã nhận'),
 (3,  3, 3, '20261025 08:15:00', '20261101', '20261106', N'Đã nhận'),
 (4,  4, 4, '20261028 14:00:00', '20261102', '20261105', N'Đã nhận'),
 (5,  5, 5, '20261030 11:20:00', '20261103', '20261107', N'Đã nhận'),
 (6,  6, 1, '20261101 16:45:00', '20261110', '20261112', N'Đã đặt'),
 (7,  7, 2, '20261102 09:10:00', '20261115', '20261118', N'Đã đặt'),
 (8,  8, 3, '20261026 13:00:00', '20261030', '20261102', N'Đã hủy'),
 (9,  1, 2, '20261024 17:30:00', '20261028', '20261030', N'Đã nhận'),
 (10, 2, 1, '20261031 10:00:00', '20261102', '20261104', N'Đã nhận');
SET IDENTITY_INSERT DAT_PHONG OFF;
GO

/* ---- PHIEU_THUE_PHONG (7 phiếu: 3 đã trả, 4 đang thuê) ---- */
SET IDENTITY_INSERT PHIEU_THUE_PHONG ON;
INSERT INTO PHIEU_THUE_PHONG (MaPhieu, MaDat, MaPhong, NgayNhanThucTe, NgayTraThucTe, GiaThue, TrangThai) VALUES
 (1, 1,  1,  '20261020 14:00:00', '20261023 11:30:00', 500000,  N'Đã trả'),
 (2, 2,  3,  '20261025 14:10:00', '20261028 10:45:00', 700000,  N'Đã trả'),
 (3, 3,  5,  '20261101 15:00:00', NULL,                1000000, N'Đang thuê'),
 (4, 4,  12, '20261102 13:30:00', NULL,                1500000, N'Đang thuê'),
 (5, 5,  15, '20261103 16:00:00', NULL,                2500000, N'Đang thuê'),
 (6, 9,  4,  '20261028 14:00:00', '20261030 12:00:00', 700000,  N'Đã trả'),
 (7, 10, 2,  '20261102 14:30:00', NULL,                500000,  N'Đang thuê');
SET IDENTITY_INSERT PHIEU_THUE_PHONG OFF;
GO

PRINT N'>>> Đã nạp dữ liệu mẫu khách sạn.';
GO
