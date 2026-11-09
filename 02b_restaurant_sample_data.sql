-- Chạy sau 01b và 02, trước 03. Chạy đúng một lần trên dữ liệu mẫu của T.
USE QL_KhachSan_NhaHang;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF EXISTS(SELECT 1 FROM dbo.MON_AN) OR EXISTS(SELECT 1 FROM dbo.HOA_DON) OR EXISTS(SELECT 1 FROM dbo.PHIEU_GOI_MON)
 THROW 51200,N'Dữ liệu nhà hàng phải trống trước khi nạp mẫu.',1;
 IF (SELECT COUNT(*) FROM dbo.PHIEU_THUE_PHONG WHERE MaPhieu IN(1,2,6) AND TrangThai=N'Đã trả')<>3
 OR NOT EXISTS(SELECT 1 FROM dbo.PHIEU_THUE_PHONG WHERE MaPhieu=3 AND TrangThai=N'Đang thuê')
 THROW 51201,N'Cần nạp đúng 01b_hotel_sample_data.sql trước.',1;
 INSERT dbo.MON_AN(TenMon,DonGia,LoaiMon,TrangThai) VALUES
 (N'Cơm chiên hải sản',80000,N'Món chính',N'Còn bán'),
 (N'Phở bò',60000,N'Món chính',N'Còn bán'),
 (N'Gỏi cuốn',40000,N'Khai vị',N'Còn bán'),
 (N'Lẩu hải sản',300000,N'Món chính',N'Còn bán'),
 (N'Nước cam',35000,N'Đồ uống',N'Còn bán'),
 (N'Cà phê sữa',30000,N'Đồ uống',N'Còn bán'),
 (N'Trái cây',50000,N'Tráng miệng',N'Còn bán'),
 (N'Kem dâu',25000,N'Tráng miệng',N'Ngừng bán');
 DECLARE @g INT,@h INT;
 INSERT dbo.PHIEU_GOI_MON(MaPhieu,MaNV,NgayGoi) VALUES(1,2,'20261021 18:00');
 SET @g=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.CHI_TIET_GOI_MON SELECT @g,MaMon,2,DonGia FROM dbo.MON_AN WHERE TenMon IN(N'Cơm chiên hải sản',N'Nước cam');
 INSERT dbo.PHIEU_GOI_MON(MaPhieu,MaNV,NgayGoi) VALUES(2,3,'20261026 08:00');
 SET @g=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.CHI_TIET_GOI_MON SELECT @g,MaMon,2,DonGia FROM dbo.MON_AN WHERE TenMon=N'Phở bò';
 INSERT dbo.PHIEU_GOI_MON(MaPhieu,MaNV,NgayGoi) VALUES(3,2,'20261102 18:00');
 SET @g=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.CHI_TIET_GOI_MON SELECT @g,MaMon,1,DonGia FROM dbo.MON_AN WHERE TenMon IN(N'Lẩu hải sản',N'Trái cây');
 INSERT dbo.HOA_DON(MaPhieu,MaNV,NgayLap) VALUES(1,2,'20261023 11:30'),(2,3,'20261028 10:45'),(6,2,'20261030 12:00');
 INSERT dbo.CHI_TIET_HOA_DON(MaHD,LoaiDong,NoiDung,SoLuong,DonGia)
 SELECT h.MaHD,N'Phòng',N'Tiền phòng theo số đêm',DATEDIFF(DAY,t.NgayNhanThucTe,t.NgayTraThucTe),t.GiaThue
 FROM dbo.HOA_DON h JOIN dbo.PHIEU_THUE_PHONG t ON t.MaPhieu=h.MaPhieu;
 INSERT dbo.CHI_TIET_HOA_DON(MaHD,LoaiDong,NoiDung,SoLuong,DonGia)
 SELECT h.MaHD,N'Món',m.TenMon,c.SoLuong,c.DonGia FROM dbo.HOA_DON h
 JOIN dbo.PHIEU_GOI_MON g ON g.MaPhieu=h.MaPhieu JOIN dbo.CHI_TIET_GOI_MON c ON c.MaGoiMon=g.MaGoiMon
 JOIN dbo.MON_AN m ON m.MaMon=c.MaMon;
 -- Nạp trước trigger nên phải tính tổng một lần tại đây.
 UPDATE h SET TongTien=(SELECT SUM(ThanhTien) FROM dbo.CHI_TIET_HOA_DON c WHERE c.MaHD=h.MaHD)
 FROM dbo.HOA_DON h;
 UPDATE dbo.HOA_DON SET TrangThai=N'Đã thanh toán' WHERE MaPhieu IN(1,2);
 COMMIT;
END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
