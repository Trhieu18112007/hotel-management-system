/* =====================================================================
   00_reset_database.sql
   Xóa TOÀN BỘ database để làm lại từ đầu (chỉ dùng khi dev/test).
   Thứ tự chạy lại cả hệ thống:
     00_reset_database.sql -> 01_hotel_tables.sql -> 01b_hotel_sample_data.sql
     -> 02_restaurant_tables.sql -> (dữ liệu mẫu nhà hàng) -> 03_logic.sql
   ===================================================================== */
USE master;
GO
IF DB_ID(N'QL_KhachSan_NhaHang') IS NOT NULL
BEGIN
    ALTER DATABASE QL_KhachSan_NhaHang SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QL_KhachSan_NhaHang;
END
GO
