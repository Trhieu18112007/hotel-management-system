USE QL_KhachSan_NhaHang;
GO
-- SELECT, WHERE, ORDER BY
SELECT MaMon,TenMon,DonGia FROM dbo.MON_AN WHERE TrangThai=N'Còn bán' ORDER BY DonGia,TenMon;
-- JOIN nhiều bảng, giá đã chụp lúc gọi
SELECT g.MaGoiMon,p.SoPhong,k.HoTen,m.TenMon,c.SoLuong,c.DonGia,
 CONVERT(DECIMAL(19,0),c.SoLuong)*c.DonGia AS ThanhTien
FROM dbo.PHIEU_GOI_MON g JOIN dbo.PHIEU_THUE_PHONG t ON t.MaPhieu=g.MaPhieu
JOIN dbo.PHONG p ON p.MaPhong=t.MaPhong JOIN dbo.DAT_PHONG d ON d.MaDat=t.MaDat
JOIN dbo.KHACH_HANG k ON k.MaKH=d.MaKH JOIN dbo.CHI_TIET_GOI_MON c ON c.MaGoiMon=g.MaGoiMon
JOIN dbo.MON_AN m ON m.MaMon=c.MaMon ORDER BY g.NgayGoi DESC;
-- GROUP BY, HAVING: món được gọi từ 2 phần trở lên
SELECT m.MaMon,m.TenMon,SUM(c.SoLuong) AS TongSoLuong,
 SUM(CONVERT(DECIMAL(19,0),c.SoLuong)*c.DonGia) AS TienMonDaGoi
FROM dbo.MON_AN m JOIN dbo.CHI_TIET_GOI_MON c ON c.MaMon=m.MaMon
GROUP BY m.MaMon,m.TenMon HAVING SUM(c.SoLuong)>=2 ORDER BY TongSoLuong DESC;
-- Doanh thu hóa đơn đã thanh toán theo tháng lập hóa đơn
SELECT YEAR(NgayLap) AS Nam,MONTH(NgayLap) AS Thang,SUM(TongTien) AS DoanhThu
FROM dbo.HOA_DON WHERE TrangThai=N'Đã thanh toán'
GROUP BY YEAR(NgayLap),MONTH(NgayLap) ORDER BY Nam,Thang;
SELECT * FROM dbo.vw_TrangThaiPhong ORDER BY SoPhong;
SELECT * FROM dbo.vw_HoaDon ORDER BY MaHD;
SELECT * FROM dbo.vw_DoanhThu ORDER BY Ngay;
GO
-- INSERT / UPDATE / DELETE minh họa trên bản ghi mới; rollback sau khi xem.
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @id INT;
 INSERT dbo.MON_AN(TenMon,DonGia,LoaiMon) VALUES(N'Món minh họa '+CONVERT(NVARCHAR(36),NEWID()),45000,N'Khai vị');
 SET @id=CONVERT(INT,SCOPE_IDENTITY());
 UPDATE dbo.MON_AN SET DonGia=50000 WHERE MaMon=@id;
 SELECT * FROM dbo.MON_AN WHERE MaMon=@id;
 DELETE dbo.MON_AN WHERE MaMon=@id;
 ROLLBACK;
END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
