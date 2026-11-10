/* Chạy trên database thử nghiệm sau 01,01b,02,02b,03.
   Mỗi ca tự rollback. Identity có thể tăng sau rollback (bình thường).
   PASS chỉ in khi các ASSERT thực sự thành công; lỗi ngoài dự kiến được THROW.
*/
USE QL_KhachSan_NhaHang;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @loai INT,@phong INT,@dat INT,@phieu INT,@goi INT,@hd INT,@m1 INT,@m2 INT;
 DECLARE @kh INT=(SELECT MIN(MaKH) FROM dbo.KHACH_HANG),
 @nv INT=(SELECT MIN(MaNV) FROM dbo.NHAN_VIEN WHERE TrangThai=1 AND VaiTro=N'Lễ tân'),
 @today DATE=CAST(GETDATE() AS DATE),@tomorrow DATE=DATEADD(DAY,1,CAST(GETDATE() AS DATE));
 INSERT dbo.LOAI_PHONG(TenLoai,GiaMotDem,SoNguoiToiDa) VALUES(N'TEST '+CONVERT(NVARCHAR(36),NEWID()),123000,2);
 SET @loai=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.PHONG(SoPhong,MaLoai,Tang) VALUES(LEFT(CONVERT(VARCHAR(36),NEWID()),10),@loai,1);
 SET @phong=CONVERT(INT,SCOPE_IDENTITY());
 EXEC dbo.sp_DatPhong @kh,@loai,@today,@tomorrow,@dat OUTPUT;
 EXEC dbo.sp_NhanPhong @dat,@phong,@phieu OUTPUT;
 IF NOT EXISTS(SELECT 1 FROM dbo.PHONG WHERE MaPhong=@phong AND TrangThai=N'Đang thuê')
 OR NOT EXISTS(SELECT 1 FROM dbo.DAT_PHONG WHERE MaDat=@dat AND TrangThai=N'Đã nhận')
 THROW 51900,N'FAIL nhận phòng và trigger trạng thái.',1;
 UPDATE dbo.LOAI_PHONG SET GiaMotDem=999000 WHERE MaLoai=@loai;
 INSERT dbo.MON_AN(TenMon,DonGia,LoaiMon) VALUES(N'TEST A '+CONVERT(NVARCHAR(36),NEWID()),10000,N'Test');
 SET @m1=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.MON_AN(TenMon,DonGia,LoaiMon) VALUES(N'TEST B '+CONVERT(NVARCHAR(36),NEWID()),20000,N'Test');
 SET @m2=CONVERT(INT,SCOPE_IDENTITY());
 DECLARE @mon dbo.DanhSachMon;
 INSERT @mon VALUES(@m1,2),(@m2,1);
 EXEC dbo.sp_GoiMon @phieu,@nv,@mon,@goi OUTPUT;
 UPDATE dbo.MON_AN SET DonGia=50000 WHERE MaMon IN(@m1,@m2);
 EXEC dbo.sp_TraPhong @phieu,@nv,@hd OUTPUT;
 IF NOT EXISTS(SELECT 1 FROM dbo.HOA_DON WHERE MaHD=@hd AND TongTien=163000)
 THROW 51900,N'FAIL giá chụp hoặc tính tiền một đêm và hai món.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.PHONG WHERE MaPhong=@phong AND TrangThai=N'Trống')
 THROW 51900,N'FAIL trả phòng và trigger.',1;
 -- UPDATE nhiều dòng, DELETE nhiều dòng, INSERT nhiều dòng.
 UPDATE dbo.CHI_TIET_HOA_DON SET SoLuong=SoLuong+1 WHERE MaHD=@hd AND LoaiDong=N'Món';
 IF (SELECT TongTien FROM dbo.HOA_DON WHERE MaHD=@hd)<>193000 THROW 51900,N'FAIL trigger UPDATE nhiều dòng.',1;
 DELETE dbo.CHI_TIET_HOA_DON WHERE MaHD=@hd AND LoaiDong=N'Món';
 IF (SELECT TongTien FROM dbo.HOA_DON WHERE MaHD=@hd)<>123000 THROW 51900,N'FAIL trigger DELETE.',1;
 INSERT dbo.CHI_TIET_HOA_DON(MaHD,LoaiDong,NoiDung,SoLuong,DonGia)
 VALUES(@hd,N'Món',N'Test 1',2,10000),(@hd,N'Món',N'Test 2',1,20000);
 IF (SELECT TongTien FROM dbo.HOA_DON WHERE MaHD=@hd)<>163000 THROW 51900,N'FAIL trigger INSERT nhiều dòng.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.vw_TrangThaiPhong WHERE MaPhong=@phong AND TrangThai=N'Trống')
 OR NOT EXISTS(SELECT 1 FROM dbo.vw_HoaDon WHERE MaHD=@hd AND TienPhong=123000 AND TienMon=40000)
 THROW 51900,N'FAIL view phòng hoặc hóa đơn.',1;
 DECLARE @before DECIMAL(19,0)=COALESCE((SELECT DoanhThu FROM dbo.vw_DoanhThu WHERE Ngay=@today),0);
 EXEC dbo.sp_ThanhToanHoaDon @hd;
 IF NOT EXISTS(SELECT 1 FROM dbo.HOA_DON WHERE MaHD=@hd AND TrangThai=N'Đã thanh toán')
 OR COALESCE((SELECT DoanhThu FROM dbo.vw_DoanhThu WHERE Ngay=@today),0)<>@before+163000
 THROW 51900,N'FAIL thanh toán hoặc view doanh thu.',1;
 ROLLBACK;
 PRINT N'PASS 01: đủ 5 procedure, 3 view, 2 trigger, giá lịch sử và rollback giao dịch thành công.';
END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
-- Phòng bảo trì không bị đổi về Trống khi trả phòng.
BEGIN TRY
 BEGIN TRAN;
 DECLARE @p INT=(SELECT MIN(MaPhieu) FROM dbo.PHIEU_THUE_PHONG WHERE TrangThai=N'Đang thuê'),@r INT;
 IF @p IS NULL THROW 51900,N'Cần phiếu đang thuê từ dữ liệu mẫu.',1;
 SELECT @r=MaPhong FROM dbo.PHIEU_THUE_PHONG WHERE MaPhieu=@p;
 UPDATE dbo.PHONG SET TrangThai=N'Bảo trì' WHERE MaPhong=@r;
 UPDATE dbo.PHIEU_THUE_PHONG SET TrangThai=N'Đã trả',NgayTraThucTe=GETDATE() WHERE MaPhieu=@p;
 IF NOT EXISTS(SELECT 1 FROM dbo.PHONG WHERE MaPhong=@r AND TrangThai=N'Bảo trì') THROW 51900,N'FAIL giữ trạng thái bảo trì.',1;
 ROLLBACK;
 PRINT N'PASS 02: giữ phòng bảo trì.';
END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
-- Bất biến dữ liệu tích hợp: các truy vấn lỗi phải trả 0 dòng.
SELECT h.MaHD,N'Sai tổng hóa đơn' AS Loi FROM dbo.HOA_DON h
OUTER APPLY(SELECT SUM(ThanhTien) AS Tong FROM dbo.CHI_TIET_HOA_DON c WHERE c.MaHD=h.MaHD) x
WHERE h.TongTien<>COALESCE(x.Tong,0);
SELECT p.MaPhong,N'Sai trạng thái phòng' AS Loi FROM dbo.PHONG p
WHERE (p.TrangThai=N'Đang thuê' AND NOT EXISTS(SELECT 1 FROM dbo.PHIEU_THUE_PHONG t WHERE t.MaPhong=p.MaPhong AND t.TrangThai=N'Đang thuê'))
OR (p.TrangThai=N'Trống' AND EXISTS(SELECT 1 FROM dbo.PHIEU_THUE_PHONG t WHERE t.MaPhong=p.MaPhong AND t.TrangThai=N'Đang thuê'));
GO
-- Các ca lỗi kỳ vọng: xác nhận đúng mã lỗi và không sót giao dịch.
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @d INT,@kh INT=(SELECT MIN(MaKH) FROM dbo.KHACH_HANG),@loai INT=(SELECT MIN(MaLoai) FROM dbo.LOAI_PHONG),
 @n DATE=DATEADD(DAY,-1,CAST(GETDATE() AS DATE)),@t DATE=DATEADD(DAY,1,CAST(GETDATE() AS DATE));
 EXEC dbo.sp_DatPhong @kh,@loai,@n,@t,@d OUTPUT;
 THROW 51901,N'FAIL đã chấp nhận ngày quá khứ.',1;
END TRY BEGIN CATCH
 DECLARE @e INT=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK;
 IF @e<>51101 THROW;
 PRINT N'PASS 03: từ chối ngày quá khứ và rollback.';
END CATCH;
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @loai INT,@d INT,@kh INT=(SELECT MIN(MaKH) FROM dbo.KHACH_HANG),
 @n DATE=CAST(GETDATE() AS DATE),@t DATE=DATEADD(DAY,1,CAST(GETDATE() AS DATE));
 INSERT dbo.LOAI_PHONG(TenLoai,GiaMotDem,SoNguoiToiDa) VALUES(N'TEST FULL '+CONVERT(NVARCHAR(36),NEWID()),100000,2);
 SET @loai=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.PHONG(SoPhong,MaLoai,Tang) VALUES(LEFT(CONVERT(VARCHAR(36),NEWID()),10),@loai,1);
 EXEC dbo.sp_DatPhong @kh,@loai,@n,@t,@d OUTPUT;
 EXEC dbo.sp_DatPhong @kh,@loai,@n,@t,@d OUTPUT;
 THROW 51901,N'FAIL đã đặt vượt số phòng.',1;
END TRY BEGIN CATCH
 DECLARE @e INT=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK;
 IF @e<>51103 THROW;
 PRINT N'PASS 04: chặn đặt vượt số phòng và rollback.';
END CATCH;
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @p INT;
 EXEC dbo.sp_NhanPhong -1,-1,@p OUTPUT;
 THROW 51901,N'FAIL nhận phòng không hợp lệ.',1;
END TRY BEGIN CATCH
 DECLARE @e INT=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK;
 IF @e<>51104 THROW;
 PRINT N'PASS 05: từ chối nhận phòng không hợp lệ.';
END CATCH;
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @p INT=(SELECT MIN(MaPhieu) FROM dbo.PHIEU_THUE_PHONG WHERE TrangThai=N'Đang thuê'),
 @nv INT=(SELECT MIN(MaNV) FROM dbo.NHAN_VIEN WHERE TrangThai=1),@g INT,
 @before INT=(SELECT COUNT(*) FROM dbo.PHIEU_GOI_MON);
 DECLARE @m dbo.DanhSachMon;
 INSERT @m SELECT MaMon,1 FROM dbo.MON_AN WHERE TrangThai=N'Ngừng bán';
 EXEC dbo.sp_GoiMon @p,@nv,@m,@g OUTPUT;
 THROW 51901,N'FAIL gọi món ngừng bán.',1;
END TRY BEGIN CATCH
 DECLARE @e INT=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK;
 IF @e<>51107 THROW;
 IF (SELECT COUNT(*) FROM dbo.PHIEU_GOI_MON)<>@before THROW 51900,N'FAIL còn phiếu gọi món sau lỗi.',1;
 PRINT N'PASS 06: từ chối món ngừng bán, không tạo phiếu dở dang.';
END CATCH;
GO
-- Lỗi xảy ra SAU UPDATE trả phòng và INSERT hóa đơn: ép tổng vượt DECIMAL(19,0).
BEGIN TRY
 BEGIN TRAN;
 DECLARE @p INT=(SELECT MIN(MaPhieu) FROM dbo.PHIEU_THUE_PHONG WHERE TrangThai=N'Đang thuê'),
 @nv INT=(SELECT MIN(MaNV) FROM dbo.NHAN_VIEN WHERE TrangThai=1 AND VaiTro=N'Lễ tân'),
 @r INT,@g INT,@h INT,@m INT;
 SELECT @r=MaPhong FROM dbo.PHIEU_THUE_PHONG WHERE MaPhieu=@p;
 INSERT dbo.MON_AN(TenMon,DonGia,LoaiMon) VALUES(N'TEST OVERFLOW '+CONVERT(NVARCHAR(36),NEWID()),999999999999,N'Test');
 SET @m=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.PHIEU_GOI_MON(MaPhieu,MaNV) VALUES(@p,@nv);
 SET @g=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.CHI_TIET_GOI_MON VALUES(@g,@m,2147483647,999999999999);
 EXEC dbo.sp_TraPhong @p,@nv,@h OUTPUT;
 THROW 51901,N'FAIL mong đợi tràn số.',1;
END TRY BEGIN CATCH
 DECLARE @e INT=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK;
 IF @e<>8115 THROW;
 IF NOT EXISTS(SELECT 1 FROM dbo.PHIEU_THUE_PHONG WHERE MaPhieu=@p AND TrangThai=N'Đang thuê' AND NgayTraThucTe IS NULL)
 OR NOT EXISTS(SELECT 1 FROM dbo.PHONG WHERE MaPhong=@r AND TrangThai=N'Đang thuê')
 OR EXISTS(SELECT 1 FROM dbo.HOA_DON WHERE MaPhieu=@p)
 THROW 51900,N'FAIL rollback trả phòng, phòng hoặc hóa đơn.',1;
 PRINT N'PASS 07: lỗi giữa giao dịch khôi phục phiếu thuê, phòng và hóa đơn.';
END CATCH;
GO
BEGIN TRY
 BEGIN TRAN;
 DECLARE @h INT=(SELECT MIN(MaHD) FROM dbo.HOA_DON WHERE TrangThai=N'Đã thanh toán');
 EXEC dbo.sp_ThanhToanHoaDon @h;
 THROW 51901,N'FAIL thanh toán hai lần.',1;
END TRY BEGIN CATCH
 DECLARE @e INT=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK;
 IF @e<>51110 THROW;
 PRINT N'PASS 08: chặn thanh toán hai lần.';
END CATCH;
GO
BEGIN TRY
 BEGIN TRAN;
 UPDATE dbo.CHI_TIET_HOA_DON SET SoLuong=SoLuong+1
 WHERE MaHD=(SELECT MIN(MaHD) FROM dbo.HOA_DON WHERE TrangThai=N'Đã thanh toán');
 THROW 51901,N'FAIL sửa hóa đơn đã thanh toán.',1;
END TRY BEGIN CATCH
 DECLARE @e INT=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK;
 IF @e<>51003 THROW;
 PRINT N'PASS 09: khóa chi tiết hóa đơn đã thanh toán.';
END CATCH;
GO
