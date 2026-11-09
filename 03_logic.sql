USE QL_KhachSan_NhaHang;
GO
CREATE OR ALTER VIEW dbo.vw_TrangThaiPhong AS
 SELECT p.MaPhong,p.SoPhong,p.Tang,p.MaLoai,l.TenLoai,l.GiaMotDem,p.TrangThai
 FROM dbo.PHONG p JOIN dbo.LOAI_PHONG l ON l.MaLoai=p.MaLoai;
GO
CREATE OR ALTER VIEW dbo.vw_HoaDon AS
 SELECT h.MaHD,h.MaPhieu,h.MaNV,n.HoTen AS NhanVien,k.HoTen AS KhachHang,p.SoPhong,
 h.NgayLap,h.TrangThai,h.TongTien,
 COALESCE(ct.TienPhong,0) AS TienPhong,COALESCE(ct.TienMon,0) AS TienMon
 FROM dbo.HOA_DON h JOIN dbo.NHAN_VIEN n ON n.MaNV=h.MaNV
 JOIN dbo.PHIEU_THUE_PHONG t ON t.MaPhieu=h.MaPhieu
 JOIN dbo.PHONG p ON p.MaPhong=t.MaPhong JOIN dbo.DAT_PHONG d ON d.MaDat=t.MaDat
 JOIN dbo.KHACH_HANG k ON k.MaKH=d.MaKH
 OUTER APPLY(SELECT SUM(CASE WHEN LoaiDong=N'Phòng' THEN ThanhTien ELSE 0 END) TienPhong,
 SUM(CASE WHEN LoaiDong=N'Món' THEN ThanhTien ELSE 0 END) TienMon
 FROM dbo.CHI_TIET_HOA_DON c WHERE c.MaHD=h.MaHD) ct;
GO
-- Doanh thu ghi nhận theo ngày lập hóa đơn đã thanh toán; chưa lưu ngày thu tiền riêng.
CREATE OR ALTER VIEW dbo.vw_DoanhThu AS
 SELECT CAST(NgayLap AS DATE) AS Ngay,COUNT_BIG(*) AS SoHoaDon,SUM(TongTien) AS DoanhThu
 FROM dbo.HOA_DON WHERE TrangThai=N'Đã thanh toán' GROUP BY CAST(NgayLap AS DATE);
GO
CREATE OR ALTER TRIGGER dbo.trg_TrangThaiPhong ON dbo.PHIEU_THUE_PHONG
AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN dbo.PHONG p ON p.MaPhong=i.MaPhong
 JOIN dbo.DAT_PHONG d ON d.MaDat=i.MaDat WHERE p.MaLoai<>d.MaLoai)
 THROW 51001,N'Phòng không cùng loại với đơn đặt.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN dbo.PHONG p ON p.MaPhong=i.MaPhong
 WHERE i.TrangThai=N'Đang thuê' AND p.TrangThai=N'Bảo trì')
 THROW 51002,N'Không thể thuê phòng bảo trì.',1;
 UPDATE p SET TrangThai=N'Trống' FROM dbo.PHONG p
 WHERE p.TrangThai=N'Đang thuê'
 AND p.MaPhong IN(SELECT MaPhong FROM inserted UNION SELECT MaPhong FROM deleted)
 AND NOT EXISTS(SELECT 1 FROM dbo.PHIEU_THUE_PHONG t WHERE t.MaPhong=p.MaPhong AND t.TrangThai=N'Đang thuê');
 UPDATE p SET TrangThai=N'Đang thuê' FROM dbo.PHONG p
 JOIN inserted i ON i.MaPhong=p.MaPhong WHERE i.TrangThai=N'Đang thuê';
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_TongTienHoaDon ON dbo.CHI_TIET_HOA_DON
AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 -- Khóa hóa đơn trước khi cộng; hỗ trợ thay đổi nhiều dòng và chuyển MaHD.
 IF EXISTS(SELECT 1 FROM dbo.HOA_DON h WITH(UPDLOCK,HOLDLOCK)
 WHERE h.MaHD IN(SELECT MaHD FROM inserted UNION SELECT MaHD FROM deleted)
 AND h.TrangThai=N'Đã thanh toán')
 THROW 51003,N'Không được sửa chi tiết hóa đơn đã thanh toán.',1;
 UPDATE h SET TongTien=COALESCE((SELECT SUM(c.ThanhTien) FROM dbo.CHI_TIET_HOA_DON c WHERE c.MaHD=h.MaHD),0)
 FROM dbo.HOA_DON h WHERE h.MaHD IN(SELECT MaHD FROM inserted UNION SELECT MaHD FROM deleted);
END;
GO
-- Mọi procedure dùng cùng khóa ứng dụng để tuần tự hóa giao dịch nghiệp vụ.
-- Backend chỉ cấp EXECUTE và SELECT, không cấp sửa trực tiếp các bảng giao dịch.
CREATE OR ALTER PROCEDURE dbo.sp_DatPhong
 @MaKH INT,@MaLoai INT,@NgayNhan DATE,@NgayTra DATE,@MaDat INT OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @lock INT,@SucChua INT,@DaDat INT;
 EXEC @lock=sys.sp_getapplock @Resource=N'QLKS_NghiepVu',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @lock<0 THROW 51100,N'Không lấy được khóa giao dịch, vui lòng thử lại.',1;
 IF @NgayNhan IS NULL OR @NgayTra IS NULL OR @NgayNhan<CAST(GETDATE() AS DATE) OR @NgayTra<=@NgayNhan
 THROW 51101,N'Ngày đặt phòng không hợp lệ.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH=@MaKH) OR NOT EXISTS(SELECT 1 FROM dbo.LOAI_PHONG WHERE MaLoai=@MaLoai)
 THROW 51102,N'Khách hàng hoặc loại phòng không tồn tại.',1;
 SELECT @SucChua=COUNT(*) FROM dbo.PHONG WITH(UPDLOCK,HOLDLOCK) WHERE MaLoai=@MaLoai AND TrangThai<>N'Bảo trì';
 SELECT @DaDat=COUNT(*) FROM dbo.DAT_PHONG d WITH(UPDLOCK,HOLDLOCK)
 WHERE d.MaLoai=@MaLoai AND
 ((d.NgayNhan<@NgayTra AND d.NgayTra>@NgayNhan AND (d.TrangThai=N'Đã đặt' OR
 (d.TrangThai=N'Đã nhận' AND EXISTS(SELECT 1 FROM dbo.PHIEU_THUE_PHONG t WHERE t.MaDat=d.MaDat AND t.TrangThai=N'Đang thuê'))))
 OR (d.TrangThai=N'Đã nhận' AND d.NgayTra<=@NgayNhan AND @NgayNhan=CAST(GETDATE() AS DATE)
 AND EXISTS(SELECT 1 FROM dbo.PHIEU_THUE_PHONG t WHERE t.MaDat=d.MaDat AND t.TrangThai=N'Đang thuê')));
 IF @DaDat>=@SucChua THROW 51103,N'Hết phòng loại này trong khoảng yêu cầu.',1;
 INSERT dbo.DAT_PHONG(MaKH,MaLoai,NgayNhan,NgayTra) VALUES(@MaKH,@MaLoai,@NgayNhan,@NgayTra);
 SET @MaDat=CONVERT(INT,SCOPE_IDENTITY());
 COMMIT;
 END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_NhanPhong @MaDat INT,@MaPhong INT,@MaPhieu INT OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @lock INT,@Gia DECIMAL(12,0);
 EXEC @lock=sys.sp_getapplock @Resource=N'QLKS_NghiepVu',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @lock<0 THROW 51100,N'Không lấy được khóa giao dịch, vui lòng thử lại.',1;
 SELECT @Gia=l.GiaMotDem FROM dbo.DAT_PHONG d WITH(UPDLOCK,HOLDLOCK)
 JOIN dbo.PHONG p WITH(UPDLOCK,HOLDLOCK) ON p.MaLoai=d.MaLoai
 JOIN dbo.LOAI_PHONG l ON l.MaLoai=d.MaLoai
 WHERE d.MaDat=@MaDat AND p.MaPhong=@MaPhong AND d.TrangThai=N'Đã đặt'
 AND p.TrangThai=N'Trống' AND d.NgayNhan<=CAST(GETDATE() AS DATE) AND d.NgayTra>CAST(GETDATE() AS DATE);
 IF @Gia IS NULL THROW 51104,N'Đơn, ngày nhận hoặc phòng không hợp lệ.',1;
 INSERT dbo.PHIEU_THUE_PHONG(MaDat,MaPhong,GiaThue) VALUES(@MaDat,@MaPhong,@Gia);
 SET @MaPhieu=CONVERT(INT,SCOPE_IDENTITY());
 UPDATE dbo.DAT_PHONG SET TrangThai=N'Đã nhận' WHERE MaDat=@MaDat;
 COMMIT;
 END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
-- Một lần gọi có nhiều món qua tham số bảng, mỗi món xuất hiện một lần.
IF TYPE_ID(N'dbo.DanhSachMon') IS NULL
 EXEC(N'CREATE TYPE dbo.DanhSachMon AS TABLE(MaMon INT PRIMARY KEY,SoLuong INT NOT NULL CHECK(SoLuong>0));');
GO
CREATE OR ALTER PROCEDURE dbo.sp_GoiMon
 @MaPhieu INT,@MaNV INT,@Mon dbo.DanhSachMon READONLY,@MaGoiMon INT OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @lock INT;
 EXEC @lock=sys.sp_getapplock @Resource=N'QLKS_NghiepVu',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @lock<0 THROW 51100,N'Không lấy được khóa giao dịch, vui lòng thử lại.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.PHIEU_THUE_PHONG WITH(UPDLOCK,HOLDLOCK) WHERE MaPhieu=@MaPhieu AND TrangThai=N'Đang thuê')
 THROW 51105,N'Chỉ gọi món khi khách đang thuê phòng.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV=@MaNV AND TrangThai=1)
 THROW 51106,N'Nhân viên không tồn tại hoặc đã nghỉ.',1;
 IF NOT EXISTS(SELECT 1 FROM @Mon) OR EXISTS(SELECT 1 FROM @Mon x LEFT JOIN dbo.MON_AN m WITH(UPDLOCK,HOLDLOCK)
 ON m.MaMon=x.MaMon WHERE m.MaMon IS NULL OR m.TrangThai<>N'Còn bán')
 THROW 51107,N'Danh sách rỗng hoặc có món không còn bán.',1;
 IF EXISTS(SELECT 1 FROM dbo.HOA_DON WHERE MaPhieu=@MaPhieu)
 THROW 51108,N'Phiếu thuê đã lập hóa đơn.',1;
 INSERT dbo.PHIEU_GOI_MON(MaPhieu,MaNV) VALUES(@MaPhieu,@MaNV);
 SET @MaGoiMon=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.CHI_TIET_GOI_MON(MaGoiMon,MaMon,SoLuong,DonGia)
 SELECT @MaGoiMon,x.MaMon,x.SoLuong,m.DonGia FROM @Mon x JOIN dbo.MON_AN m ON m.MaMon=x.MaMon;
 COMMIT;
 END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_TraPhong @MaPhieu INT,@MaNV INT,@MaHD INT OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @lock INT,@Nhan DATETIME,@Tra DATETIME=GETDATE(),@Gia DECIMAL(12,0),@Dem INT;
 EXEC @lock=sys.sp_getapplock @Resource=N'QLKS_NghiepVu',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @lock<0 THROW 51100,N'Không lấy được khóa giao dịch, vui lòng thử lại.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV=@MaNV AND TrangThai=1 AND VaiTro IN(N'Quản lý',N'Lễ tân'))
 THROW 51106,N'Nhân viên không có quyền lập hóa đơn.',1;
 SELECT @Nhan=NgayNhanThucTe,@Gia=GiaThue FROM dbo.PHIEU_THUE_PHONG WITH(UPDLOCK,HOLDLOCK)
 WHERE MaPhieu=@MaPhieu AND TrangThai=N'Đang thuê';
 IF @Nhan IS NULL OR @Nhan>@Tra THROW 51109,N'Phiếu không đang thuê hoặc ngày nhận ở tương lai.',1;
 IF EXISTS(SELECT 1 FROM dbo.HOA_DON WHERE MaPhieu=@MaPhieu) THROW 51108,N'Phiếu thuê đã lập hóa đơn.',1;
 -- Tính số đêm theo ngày lịch; cùng ngày tính một đêm.
 SET @Dem=CASE WHEN DATEDIFF(DAY,@Nhan,@Tra)<1 THEN 1 ELSE DATEDIFF(DAY,@Nhan,@Tra) END;
 UPDATE dbo.PHIEU_THUE_PHONG SET NgayTraThucTe=@Tra,TrangThai=N'Đã trả' WHERE MaPhieu=@MaPhieu;
 INSERT dbo.HOA_DON(MaPhieu,MaNV) VALUES(@MaPhieu,@MaNV);
 SET @MaHD=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.CHI_TIET_HOA_DON(MaHD,LoaiDong,NoiDung,SoLuong,DonGia)
 VALUES(@MaHD,N'Phòng',N'Tiền phòng theo số đêm',@Dem,@Gia);
 INSERT dbo.CHI_TIET_HOA_DON(MaHD,LoaiDong,NoiDung,SoLuong,DonGia)
 SELECT @MaHD,N'Món',m.TenMon,c.SoLuong,c.DonGia FROM dbo.PHIEU_GOI_MON g
 JOIN dbo.CHI_TIET_GOI_MON c ON c.MaGoiMon=g.MaGoiMon JOIN dbo.MON_AN m ON m.MaMon=c.MaMon
 WHERE g.MaPhieu=@MaPhieu;
 COMMIT;
 END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_ThanhToanHoaDon @MaHD INT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @lock INT,@Tong DECIMAL(19,0),@ChiTiet DECIMAL(19,0);
 EXEC @lock=sys.sp_getapplock @Resource=N'QLKS_NghiepVu',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @lock<0 THROW 51100,N'Không lấy được khóa giao dịch, vui lòng thử lại.',1;
 SELECT @Tong=h.TongTien FROM dbo.HOA_DON h WITH(UPDLOCK,HOLDLOCK)
 JOIN dbo.PHIEU_THUE_PHONG t ON t.MaPhieu=h.MaPhieu
 WHERE h.MaHD=@MaHD AND h.TrangThai=N'Chưa thanh toán' AND t.TrangThai=N'Đã trả';
 SELECT @ChiTiet=SUM(ThanhTien) FROM dbo.CHI_TIET_HOA_DON WITH(UPDLOCK,HOLDLOCK) WHERE MaHD=@MaHD;
 IF @Tong IS NULL OR @ChiTiet IS NULL OR @Tong<>@ChiTiet OR @Tong<=0
 THROW 51110,N'Hóa đơn không hợp lệ hoặc đã thanh toán.',1;
 UPDATE dbo.HOA_DON SET TrangThai=N'Đã thanh toán' WHERE MaHD=@MaHD;
 COMMIT;
 END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
