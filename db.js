// =====================================================================
// FILE: backend/db.js
// PHỤ TRÁCH: Khang (Backend Developer)
// MÔ TẢ: Kết nối SQL Server (QL_KhachSan_NhaHang) & khởi tạo bcrypt mẫu
// =====================================================================

const sql = require('mssql');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const dbConfig = {
    user: process.env.DB_USER || 'sa',
    password: process.env.DB_PASSWORD || '123456',
    server: process.env.DB_SERVER || 'localhost',
    database: process.env.DB_NAME || 'QL_KhachSan_NhaHang',
    port: parseInt(process.env.DB_PORT, 10) || 1433,
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

const poolPromise = new sql.ConnectionPool(dbConfig)
    .connect()
    .then(async (pool) => {
        console.log('>>> Đã kết nối SQL Server: QL_KhachSan_NhaHang');

        // Tự động băm mật khẩu mặc định "123456" cho các dòng đang là 'CHO_BCRYPT'
        const defaultHash = await bcrypt.hash('123456', 10);
        await pool.request()
            .input('MatKhauHash', sql.VarChar(255), defaultHash)
            .query(`
                UPDATE NHAN_VIEN 
                SET MatKhauHash = @MatKhauHash 
                WHERE MatKhauHash = 'CHO_BCRYPT'
            `);

        return pool;
    })
    .catch((err) => {
        console.error('Lỗi kết nối Database:', err.message);
        process.exit(1);
    });

module.exports = { sql, poolPromise };