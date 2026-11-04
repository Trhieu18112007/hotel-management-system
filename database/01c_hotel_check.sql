/* =====================================================================
   01c_hotel_check.sql  -  Kiểm tra tính liên kết & ràng buộc (T)
   Cách đọc: PHẦN A -> mọi truy vấn phải trả về 0 dòng (0 lỗi).
             PHẦN B -> mọi dòng in ra phải bắt đầu bằng PASS (xem tab Messages).
   Chạy được nhiều lần, không để lại thay đổi dữ liệu.
   ===================================================================== */
USE QL_KhachSan_NhaHang;
GO
SET NOCOUNT ON;

/* ================= PHẦN A: KIỂM TRA DỮ LIỆU ================= */

PRINT N'--- A0. Số dòng mỗi bảng (mẫu: 4 / 8 / 5 / 15 / 10 / 7) ---';
SELECT 'NHAN_VIEN' Bang, COUNT(*) SoDong FROM NHAN_VIEN UNION ALL
SELECT 'KHACH_HANG',      COUNT(*) FROM KHACH_HANG UNION ALL
SELECT 'LOAI_PHONG',      COUNT(*) FROM LOAI_PHONG UNION ALL
SELECT 'PHONG',           COUNT(*) FROM PHONG UNION ALL
SELECT 'DAT_PHONG',       COUNT(*) FROM DAT_PHONG UNION ALL
SELECT 'PHIEU_THUE_PHONG',COUNT(*) FROM PHIEU_THUE_PHONG;

PRINT N'--- A1. Kiểm tra toàn bộ FK/CHECK trên dữ liệu hiện có (phải 0 dòng) ---';
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;

PRINT N'--- A2. Phòng "Đang thuê" nhưng KHÔNG có phiếu đang thuê, hoặc ngược lại (phải 0 dòng) ---';
SELECT p.MaPhong, p.SoPhong, p.TrangThai
FROM PHONG p
WHERE (p.TrangThai = N'Đang thuê'
       AND NOT EXISTS (SELECT 1 FROM PHIEU_THUE_PHONG t WHERE t.MaPhong = p.MaPhong AND t.TrangThai = N'Đang thuê'))
   OR (p.TrangThai <> N'Đang thuê'
       AND EXISTS     (SELECT 1 FROM PHIEU_THUE_PHONG t WHERE t.MaPhong = p.MaPhong AND t.TrangThai = N'Đang thuê'));

PRINT N'--- A3. Đơn "Đã nhận" mà chưa có phiếu thuê, hoặc đơn khác "Đã nhận" mà đã có phiếu (phải 0 dòng) ---';
SELECT d.MaDat, d.TrangThai
FROM DAT_PHONG d
LEFT JOIN PHIEU_THUE_PHONG t ON t.MaDat = d.MaDat
WHERE (d.TrangThai = N'Đã nhận' AND t.MaPhieu IS NULL)
   OR (d.TrangThai <> N'Đã nhận' AND t.MaPhieu IS NOT NULL);

PRINT N'--- A4. Phòng được gán khác LOẠI với loại khách đã đặt (phải 0 dòng; nếu muốn cho nâng hạng thì bỏ kiểm tra này) ---';
SELECT t.MaPhieu, d.MaLoai AS LoaiDat, p.MaLoai AS LoaiPhong
FROM PHIEU_THUE_PHONG t
JOIN DAT_PHONG d ON d.MaDat = t.MaDat
JOIN PHONG p     ON p.MaPhong = t.MaPhong
WHERE d.MaLoai <> p.MaLoai;

PRINT N'--- A5. Hai phiếu thuê trùng thời gian trên cùng một phòng (phải 0 dòng) ---';
SELECT a.MaPhieu AS Phieu1, b.MaPhieu AS Phieu2, a.MaPhong
FROM PHIEU_THUE_PHONG a
JOIN PHIEU_THUE_PHONG b
  ON a.MaPhong = b.MaPhong AND a.MaPhieu < b.MaPhieu
 AND a.NgayNhanThucTe < ISNULL(b.NgayTraThucTe, '99991231')
 AND b.NgayNhanThucTe < ISNULL(a.NgayTraThucTe, '99991231');

PRINT N'--- A6. Một khách có 2 đơn đặt trùng ngày trùng loại (cảnh báo, nên 0 dòng) ---';
SELECT a.MaDat, b.MaDat, a.MaKH
FROM DAT_PHONG a JOIN DAT_PHONG b
  ON a.MaKH = b.MaKH AND a.MaLoai = b.MaLoai AND a.MaDat < b.MaDat
 AND a.TrangThai <> N'Đã hủy' AND b.TrangThai <> N'Đã hủy'
 AND a.NgayNhan < b.NgayTra AND b.NgayNhan < a.NgayTra;

PRINT N'--- A7. Nối đủ chuỗi KHACH_HANG -> DAT_PHONG -> PHIEU_THUE_PHONG -> PHONG -> LOAI_PHONG ---';
SELECT t.MaPhieu, kh.HoTen, lp.TenLoai, ph.SoPhong,
       t.NgayNhanThucTe, t.NgayTraThucTe, t.GiaThue, t.TrangThai
FROM PHIEU_THUE_PHONG t
JOIN DAT_PHONG d   ON d.MaDat   = t.MaDat
JOIN KHACH_HANG kh ON kh.MaKH   = d.MaKH
JOIN PHONG ph      ON ph.MaPhong= t.MaPhong
JOIN LOAI_PHONG lp ON lp.MaLoai = ph.MaLoai
ORDER BY t.MaPhieu;
GO

/* ================= PHẦN B: THỬ CỐ TÌNH SAI (phải bị chặn) ================= */
PRINT N'=== PHẦN B: mỗi ca phải PASS ===';

-- B1: trùng CCCD
BEGIN TRY
  BEGIN TRAN;
  INSERT INTO KHACH_HANG (HoTen, CCCD, SDT) VALUES (N'Test', '079201001234', '0900000000');
  PRINT N'FAIL B1: trùng CCCD vẫn thêm được'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B1 (trùng CCCD bị chặn)';
END CATCH
GO
-- B2: CCCD chứa chữ
BEGIN TRY
  BEGIN TRAN;
  INSERT INTO KHACH_HANG (HoTen, CCCD, SDT) VALUES (N'Test', '07920100abcd', '0900000000');
  PRINT N'FAIL B2: CCCD có chữ vẫn thêm được'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B2 (CCCD sai định dạng bị chặn)';
END CATCH
GO
-- B3: SĐT sai
BEGIN TRY
  BEGIN TRAN;
  INSERT INTO KHACH_HANG (HoTen, CCCD, SDT) VALUES (N'Test', '079209999999', '12345');
  PRINT N'FAIL B3: SĐT sai vẫn thêm được'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B3 (SĐT sai bị chặn)';
END CATCH
GO
-- B4: giá loại phòng <= 0
BEGIN TRY
  BEGIN TRAN;
  INSERT INTO LOAI_PHONG (TenLoai, GiaMotDem, SoNguoiToiDa) VALUES (N'Lỗi', 0, 2);
  PRINT N'FAIL B4: giá = 0 vẫn thêm được'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B4 (giá <= 0 bị chặn)';
END CATCH
GO
-- B5: trạng thái phòng không hợp lệ
BEGIN TRY
  BEGIN TRAN;
  UPDATE PHONG SET TrangThai = N'Đã đặt' WHERE MaPhong = 1;
  PRINT N'FAIL B5: trạng thái sai vẫn cập nhật được'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B5 (trạng thái phòng sai bị chặn)';
END CATCH
GO
-- B6: phòng gắn loại không tồn tại (FK)
BEGIN TRY
  BEGIN TRAN;
  INSERT INTO PHONG (SoPhong, MaLoai, Tang) VALUES ('999', 999, 9);
  PRINT N'FAIL B6: loại phòng không tồn tại vẫn thêm được'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B6 (FK PHONG -> LOAI_PHONG hoạt động)';
END CATCH
GO
-- B7: ngày trả <= ngày nhận
BEGIN TRY
  BEGIN TRAN;
  INSERT INTO DAT_PHONG (MaKH, MaLoai, NgayNhan, NgayTra) VALUES (1, 1, '20261201', '20261201');
  PRINT N'FAIL B7: ngày trả = ngày nhận vẫn thêm được'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B7 (ngày trả phải sau ngày nhận)';
END CATCH
GO
-- B8: xóa khách đã có đơn đặt
BEGIN TRY
  BEGIN TRAN;
  DELETE FROM KHACH_HANG WHERE MaKH = 1;
  PRINT N'FAIL B8: xóa được khách đã có đơn đặt'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B8 (không xóa được khách còn dữ liệu liên quan)';
END CATCH
GO
-- B9: xóa loại phòng đang được dùng
BEGIN TRY
  BEGIN TRAN;
  DELETE FROM LOAI_PHONG WHERE MaLoai = 1;
  PRINT N'FAIL B9: xóa được loại phòng đang dùng'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B9 (không xóa được loại phòng đang dùng)';
END CATCH
GO
-- B10: một phòng có 2 phiếu "Đang thuê" (phòng 105 đang có phiếu 3; dùng đơn 6 chưa nhận)
BEGIN TRY
  BEGIN TRAN;
  INSERT INTO PHIEU_THUE_PHONG (MaDat, MaPhong, GiaThue) VALUES (6, 5, 1000000);
  PRINT N'FAIL B10: 1 phòng có 2 phiếu đang thuê'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B10 (1 phòng không thể có 2 phiếu đang thuê)';
END CATCH
GO
-- B11: một đơn đặt nhận phòng 2 lần (đơn 3 đã có phiếu 3)
BEGIN TRY
  BEGIN TRAN;
  INSERT INTO PHIEU_THUE_PHONG (MaDat, MaPhong, GiaThue) VALUES (3, 6, 500000);
  PRINT N'FAIL B11: 1 đơn nhận phòng 2 lần'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B11 (1 đơn đặt chỉ nhận phòng 1 lần)';
END CATCH
GO
-- B12: trạng thái phiếu mâu thuẫn ngày trả (Đã trả nhưng chưa có ngày trả)
BEGIN TRY
  BEGIN TRAN;
  UPDATE PHIEU_THUE_PHONG SET TrangThai = N'Đã trả' WHERE MaPhieu = 3;  -- NgayTraThucTe đang NULL
  PRINT N'FAIL B12: phiếu "Đã trả" nhưng chưa có ngày trả'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B12 (trạng thái phiếu phải khớp ngày trả)';
END CATCH
GO
-- B13: trả phòng trước khi nhận
BEGIN TRY
  BEGIN TRAN;
  UPDATE PHIEU_THUE_PHONG SET NgayTraThucTe = '20260101', TrangThai = N'Đã trả' WHERE MaPhieu = 3;
  PRINT N'FAIL B13: ngày trả thực tế trước ngày nhận'; ROLLBACK;
END TRY BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'PASS B13 (ngày trả thực tế >= ngày nhận thực tế)';
END CATCH
GO
