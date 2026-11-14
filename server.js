// =====================================================================
// FILE: backend/server.js
// PHỤ TRÁCH: Khang (Backend Developer)
// CÔNG NGHỆ: Node.js + Express + MSSQL
// ĐỒNG BỘ 100% VỚI: 01_hotel_tables.sql, 01b_hotel_sample_data.sql, 01c_hotel_check.sql
// =====================================================================

const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const { sql, poolPromise } = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

// =====================================================================
// HÀM KIỂM TRA DỮ LIỆU ĐẦU VÀO (VALIDATION THEO RÀNG BUỘC CỦA T)
// =====================================================================
const isValidCCCD = (cccd) => /^[0-9]{9}$|^[0-9]{12}$/.test(String(cccd || '').trim());
const isValidSDT = (sdt) => /^0[0-9]{9,10}$/.test(String(sdt || '').trim());
const isValidEmail = (email) => !email || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email).trim());

const TRANG_THAI_PHONG_HOP_LE = ['Trống', 'Đang thuê', 'Bảo trì'];
const TRANG_THAI_DAT_HOP_LE = ['Đã đặt', 'Đã nhận', 'Đã hủy'];

// =====================================================================
// 1. API ĐĂNG NHẬP & DASHBOARD (Hỗ trợ giao diện của Tài)
// =====================================================================
app.post('/api/auth/login', async (req, res) => {
    try {
        const { TenDangNhap, MatKhau } = req.body;
        if (!TenDangNhap || !MatKhau) {
            return res.status(400).json({ error: 'Vui lòng nhập Tên đăng nhập và Mật khẩu!' });
        }

        const pool = await poolPromise;
        const result = await pool.request()
            .input('TenDangNhap', sql.VarChar(50), TenDangNhap.trim())
            .query('SELECT * FROM NHAN_VIEN WHERE TenDangNhap = @TenDangNhap AND TrangThai = 1');

        if (result.recordset.length === 0) {
            return res.status(401).json({ error: 'Tài khoản không tồn tại hoặc đã ngừng hoạt động!' });
        }

        const nv = result.recordset[0];
        const isMatch = await bcrypt.compare(String(MatKhau), nv.MatKhauHash);
        if (!isMatch) {
            return res.status(401).json({ error: 'Mật khẩu không chính xác!' });
        }

        res.json({
            message: 'Đăng nhập thành công',
            nhanVien: {
                MaNV: nv.MaNV,
                HoTen: nv.HoTen,
                TenDangNhap: nv.TenDangNhap,
                VaiTro: nv.VaiTro,
                SDT: nv.SDT
            }
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/dashboard', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query(`
            SELECT 
                (SELECT COUNT(*) FROM PHONG) AS TongSoPhong,
                (SELECT COUNT(*) FROM PHONG WHERE TrangThai = N'Trống') AS SoPhongTrong,
                (SELECT COUNT(*) FROM PHONG WHERE TrangThai = N'Đang thuê') AS SoPhongDangThue,
                (SELECT COUNT(*) FROM PHONG WHERE TrangThai = N'Bảo trì') AS SoPhongBaoTri,
                (SELECT COUNT(*) FROM KHACH_HANG) AS SoKhachHang,
                (SELECT COUNT(*) FROM DAT_PHONG WHERE TrangThai = N'Đã đặt') AS SoDonChoNhan
        `);
        res.json(result.recordset[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// =====================================================================
// 2. API QUẢN LÝ KHÁCH HÀNG (Thêm, Sửa, Xóa, Xem danh sách, Tìm kiếm)
// =====================================================================
app.get('/api/khach-hang', async (req, res) => {
    try {
        const { search } = req.query;
        const pool = await poolPromise;
        const request = pool.request();
        let query = 'SELECT * FROM KHACH_HANG';

        if (search && search.trim() !== '') {
            query += ' WHERE HoTen LIKE @search OR SDT LIKE @search OR CCCD LIKE @search';
            request.input('search', sql.NVarChar(100), `%${search.trim()}%`);
        }
        query += ' ORDER BY MaKH DESC';

        const result = await request.query(query);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/khach-hang', async (req, res) => {
    try {
        const { HoTen, CCCD, SDT, Email, DiaChi } = req.body;

        if (!HoTen || String(HoTen).trim().length === 0) {
            return res.status(400).json({ error: 'Họ tên khách hàng không được để trống!' });
        }
        if (!isValidCCCD(CCCD)) {
            return res.status(400).json({ error: 'CCCD/CMND phải gồm đúng 9 hoặc 12 chữ số!' });
        }
        if (!isValidSDT(SDT)) {
            return res.status(400).json({ error: 'SĐT phải gồm 10-11 chữ số và bắt đầu bằng số 0!' });
        }
        if (!isValidEmail(Email)) {
            return res.status(400).json({ error: 'Định dạng Email không hợp lệ!' });
        }

        const pool = await poolPromise;
        const result = await pool.request()
            .input('HoTen', sql.NVarChar(100), String(HoTen).trim())
            .input('CCCD', sql.VarChar(12), String(CCCD).trim())
            .input('SDT', sql.VarChar(11), String(SDT).trim())
            .input('Email', sql.VarChar(100), Email ? String(Email).trim() : null)
            .input('DiaChi', sql.NVarChar(200), DiaChi ? String(DiaChi).trim() : null)
            .query(`
                INSERT INTO KHACH_HANG (HoTen, CCCD, SDT, Email, DiaChi)
                OUTPUT INSERTED.*
                VALUES (@HoTen, @CCCD, @SDT, @Email, @DiaChi)
            `);

        res.status(201).json(result.recordset[0]);
    } catch (err) {
        res.status(400).json({ error: 'Lỗi thêm khách hàng (có thể trùng CCCD): ' + err.message });
    }
});

app.put('/api/khach-hang/:id', async (req, res) => {
    try {
        const maKH = parseInt(req.params.id, 10);
        const { HoTen, CCCD, SDT, Email, DiaChi } = req.body;

        if (!HoTen || String(HoTen).trim().length === 0) {
            return res.status(400).json({ error: 'Họ tên không được để trống!' });
        }
        if (!isValidCCCD(CCCD)) {
            return res.status(400).json({ error: 'CCCD/CMND phải gồm đúng 9 hoặc 12 chữ số!' });
        }
        if (!isValidSDT(SDT)) {
            return res.status(400).json({ error: 'SĐT phải gồm 10-11 chữ số và bắt đầu bằng số 0!' });
        }
        if (!isValidEmail(Email)) {
            return res.status(400).json({ error: 'Định dạng Email không hợp lệ!' });
        }

        const pool = await poolPromise;
        const result = await pool.request()
            .input('MaKH', sql.Int, maKH)
            .input('HoTen', sql.NVarChar(100), String(HoTen).trim())
            .input('CCCD', sql.VarChar(12), String(CCCD).trim())
            .input('SDT', sql.VarChar(11), String(SDT).trim())
            .input('Email', sql.VarChar(100), Email ? String(Email).trim() : null)
            .input('DiaChi', sql.NVarChar(200), DiaChi ? String(DiaChi).trim() : null)
            .query(`
                UPDATE KHACH_HANG
                SET HoTen = @HoTen, CCCD = @CCCD, SDT = @SDT, Email = @Email, DiaChi = @DiaChi
                OUTPUT INSERTED.*
                WHERE MaKH = @MaKH
            `);

        if (result.recordset.length === 0) {
            return res.status(404).json({ error: 'Không tìm thấy khách hàng!' });
        }
        res.json({ message: 'Cập nhật thông tin khách hàng thành công', data: result.recordset[0] });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.delete('/api/khach-hang/:id', async (req, res) => {
    try {
        const maKH = parseInt(req.params.id, 10);
        const pool = await poolPromise;
        const result = await pool.request()
            .input('MaKH', sql.Int, maKH)
            .query('DELETE FROM KHACH_HANG WHERE MaKH = @MaKH');

        if (result.rowsAffected[0] === 0) {
            return res.status(404).json({ error: 'Không tìm thấy khách hàng!' });
        }
        res.json({ message: 'Xóa khách hàng thành công' });
    } catch (err) {
        res.status(400).json({ error: 'Không thể xóa khách hàng đã có đơn đặt phòng hoặc hóa đơn!' });
    }
});

// =====================================================================
// 3. API QUẢN LÝ LOẠI PHÒNG & PHÒNG (Danh sách, Phòng trống, Cập nhật TT)
// =====================================================================
app.get('/api/loai-phong', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT * FROM LOAI_PHONG ORDER BY MaLoai');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/phong', async (req, res) => {
    try {
        const { trangThai, maLoai } = req.query;
        const pool = await poolPromise;
        const request = pool.request();
        let conditions = [];

        if (trangThai) {
            conditions.push('p.TrangThai = @TrangThai');
            request.input('TrangThai', sql.NVarChar(20), trangThai);
        }
        if (maLoai) {
            conditions.push('p.MaLoai = @MaLoai');
            request.input('MaLoai', sql.Int, parseInt(maLoai, 10));
        }

        const whereClause = conditions.length > 0 ? 'WHERE ' + conditions.join(' AND ') : '';
        const result = await request.query(`
            SELECT p.MaPhong, p.SoPhong, p.MaLoai, lp.TenLoai, lp.GiaMotDem, lp.SoNguoiToiDa, p.Tang, p.TrangThai
            FROM PHONG p
            INNER JOIN LOAI_PHONG lp ON p.MaLoai = lp.MaLoai
            ${whereClause}
            ORDER BY p.SoPhong
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/phong/trong', async (req, res) => {
    try {
        const { maLoai } = req.query;
        const pool = await poolPromise;
        const request = pool.request();
        let extraCondition = '';

        if (maLoai) {
            extraCondition = 'AND p.MaLoai = @MaLoai';
            request.input('MaLoai', sql.Int, parseInt(maLoai, 10));
        }

        const result = await request.query(`
            SELECT p.MaPhong, p.SoPhong, p.MaLoai, lp.TenLoai, lp.GiaMotDem, lp.SoNguoiToiDa, p.Tang, p.TrangThai
            FROM PHONG p
            INNER JOIN LOAI_PHONG lp ON p.MaLoai = lp.MaLoai
            WHERE p.TrangThai = N'Trống' ${extraCondition}
            ORDER BY p.SoPhong
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/phong', async (req, res) => {
    try {
        const { SoPhong, MaLoai, Tang, TrangThai } = req.body;
        const tt = TrangThai || 'Trống';

        if (!SoPhong || !MaLoai || !Tang || Tang <= 0) {
            return res.status(400).json({ error: 'Vui lòng nhập đầy đủ Số phòng, Mã loại phòng và Tầng (> 0)!' });
        }
        if (!TRANG_THAI_PHONG_HOP_LE.includes(tt)) {
            return res.status(400).json({ error: "Trạng thái phòng chỉ nhận: 'Trống', 'Đang thuê', hoặc 'Bảo trì'!" });
        }

        const pool = await poolPromise;
        const result = await pool.request()
            .input('SoPhong', sql.VarChar(10), String(SoPhong).trim())
            .input('MaLoai', sql.Int, parseInt(MaLoai, 10))
            .input('Tang', sql.Int, parseInt(Tang, 10))
            .input('TrangThai', sql.NVarChar(20), tt)
            .query(`
                INSERT INTO PHONG (SoPhong, MaLoai, Tang, TrangThai)
                OUTPUT INSERTED.*
                VALUES (@SoPhong, @MaLoai, @Tang, @TrangThai)
            `);
        res.status(201).json(result.recordset[0]);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.put('/api/phong/:id', async (req, res) => {
    try {
        const maPhong = parseInt(req.params.id, 10);
        const { SoPhong, MaLoai, Tang, TrangThai } = req.body;

        if (TrangThai && !TRANG_THAI_PHONG_HOP_LE.includes(TrangThai)) {
            return res.status(400).json({ error: "Trạng thái phòng chỉ nhận: 'Trống', 'Đang thuê', hoặc 'Bảo trì'!" });
        }

        const pool = await poolPromise;
        const result = await pool.request()
            .input('MaPhong', sql.Int, maPhong)
            .input('SoPhong', sql.VarChar(10), String(SoPhong).trim())
            .input('MaLoai', sql.Int, parseInt(MaLoai, 10))
            .input('Tang', sql.Int, parseInt(Tang, 10))
            .input('TrangThai', sql.NVarChar(20), TrangThai)
            .query(`
                UPDATE PHONG
                SET SoPhong = @SoPhong, MaLoai = @MaLoai, Tang = @Tang, TrangThai = @TrangThai
                OUTPUT INSERTED.*
                WHERE MaPhong = @MaPhong
            `);

        if (result.recordset.length === 0) {
            return res.status(404).json({ error: 'Không tìm thấy phòng!' });
        }
        res.json({ message: 'Cập nhật phòng thành công', data: result.recordset[0] });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.patch('/api/phong/:id/trang-thai', async (req, res) => {
    try {
        const maPhong = parseInt(req.params.id, 10);
        const { TrangThai } = req.body;

        if (!TRANG_THAI_PHONG_HOP_LE.includes(TrangThai)) {
            return res.status(400).json({ error: "Trạng thái phòng chỉ nhận: 'Trống', 'Đang thuê', hoặc 'Bảo trì'!" });
        }

        const pool = await poolPromise;
        await pool.request()
            .input('MaPhong', sql.Int, maPhong)
            .input('TrangThai', sql.NVarChar(20), TrangThai)
            .query('UPDATE PHONG SET TrangThai = @TrangThai WHERE MaPhong = @MaPhong');

        res.json({ message: 'Cập nhật trạng thái phòng thành công' });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.delete('/api/phong/:id', async (req, res) => {
    try {
        const maPhong = parseInt(req.params.id, 10);
        const pool = await poolPromise;
        await pool.request()
            .input('MaPhong', sql.Int, maPhong)
            .query('DELETE FROM PHONG WHERE MaPhong = @MaPhong');
        res.json({ message: 'Xóa phòng thành công' });
    } catch (err) {
        res.status(400).json({ error: 'Không thể xóa phòng đã có phiếu thuê!' });
    }
});

// =====================================================================
// 4. API ĐẶT PHÒNG (Đặt theo MaLoai - Bảng DAT_PHONG)
// =====================================================================
app.get('/api/dat-phong', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query(`
            SELECT dp.MaDat, dp.MaKH, kh.HoTen, kh.SDT, dp.MaLoai, lp.TenLoai, lp.GiaMotDem,
                   dp.NgayDat, dp.NgayNhan, dp.NgayTra, dp.TrangThai
            FROM DAT_PHONG dp
            INNER JOIN KHACH_HANG kh ON dp.MaKH = kh.MaKH
            INNER JOIN LOAI_PHONG lp ON dp.MaLoai = lp.MaLoai
            ORDER BY dp.MaDat DESC
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/dat-phong', async (req, res) => {
    try {
        const { MaKH, MaLoai, NgayNhan, NgayTra } = req.body;
        if (!MaKH || !MaLoai || !NgayNhan || !NgayTra) {
            return res.status(400).json({ error: 'Vui lòng cung cấp đủ MaKH, MaLoai, NgayNhan, NgayTra!' });
        }
        if (new Date(NgayTra) <= new Date(NgayNhan)) {
            return res.status(400).json({ error: 'Ngày trả phòng phải sau ngày nhận phòng!' });
        }

        const pool = await poolPromise;

        // Ưu tiên gọi Stored Procedure sp_DatPhong của Hiền nếu đã tạo
        const spCheck = await pool.request().query("SELECT OBJECT_ID('sp_DatPhong', 'P') AS SpId");
        if (spCheck.recordset[0].SpId) {
            const spRes = await pool.request()
                .input('MaKH', sql.Int, parseInt(MaKH, 10))
                .input('MaLoai', sql.Int, parseInt(MaLoai, 10))
                .input('NgayNhan', sql.Date, NgayNhan)
                .input('NgayTra', sql.Date, NgayTra)
                .execute('sp_DatPhong');
            return res.status(201).json({ message: 'Đặt phòng thành công (via SP)', data: spRes.recordset?.[0] });
        }

        // Fallback Transaction chuẩn theo 01_hotel_tables.sql & 01c_hotel_check.sql
        const result = await pool.request()
            .input('MaKH', sql.Int, parseInt(MaKH, 10))
            .input('MaLoai', sql.Int, parseInt(MaLoai, 10))
            .input('NgayNhan', sql.Date, NgayNhan)
            .input('NgayTra', sql.Date, NgayTra)
            .query(`
                INSERT INTO DAT_PHONG (MaKH, MaLoai, NgayNhan, NgayTra, TrangThai)
                OUTPUT INSERTED.*
                VALUES (@MaKH, @MaLoai, @NgayNhan, @NgayTra, N'Đã đặt')
            `);

        res.status(201).json({ message: 'Đặt phòng thành công', data: result.recordset[0] });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.patch('/api/dat-phong/:id/huy', async (req, res) => {
    try {
        const maDat = parseInt(req.params.id, 10);
        const pool = await poolPromise;
        const result = await pool.request()
            .input('MaDat', sql.Int, maDat)
            .query(`
                UPDATE DAT_PHONG 
                SET TrangThai = N'Đã hủy' 
                OUTPUT INSERTED.*
                WHERE MaDat = @MaDat AND TrangThai = N'Đã đặt'
            `);

        if (result.recordset.length === 0) {
            return res.status(400).json({ error: 'Chỉ có thể hủy đơn đặt đang ở trạng thái Đã đặt!' });
        }
        res.json({ message: 'Đã hủy đơn đặt phòng', data: result.recordset[0] });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// =====================================================================
// 5. API NHẬN PHÒNG & TRẢ PHÒNG (Bảng PHIEU_THUE_PHONG)
// =====================================================================
app.get('/api/phieu-thue', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query(`
            SELECT t.MaPhieu, t.MaDat, kh.MaKH, kh.HoTen, kh.SDT,
                   ph.MaPhong, ph.SoPhong, lp.MaLoai, lp.TenLoai,
                   t.NgayNhanThucTe, t.NgayTraThucTe, t.GiaThue, t.TrangThai
            FROM PHIEU_THUE_PHONG t
            INNER JOIN DAT_PHONG d   ON d.MaDat    = t.MaDat
            INNER JOIN KHACH_HANG kh ON kh.MaKH    = d.MaKH
            INNER JOIN PHONG ph      ON ph.MaPhong = t.MaPhong
            INNER JOIN LOAI_PHONG lp ON lp.MaLoai  = ph.MaLoai
            ORDER BY t.MaPhieu DESC
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/nhan-phong', async (req, res) => {
    try {
        const { MaDat, MaPhong } = req.body;
        if (!MaDat || !MaPhong) {
            return res.status(400).json({ error: 'Vui lòng cung cấp MaDat và MaPhong cụ thể để nhận phòng!' });
        }

        const pool = await poolPromise;

        // Ưu tiên gọi Stored Procedure sp_NhanPhong của Hiền nếu đã có
        const spCheck = await pool.request().query("SELECT OBJECT_ID('sp_NhanPhong', 'P') AS SpId");
        if (spCheck.recordset[0].SpId) {
            const spRes = await pool.request()
                .input('MaDat', sql.Int, parseInt(MaDat, 10))
                .input('MaPhong', sql.Int, parseInt(MaPhong, 10))
                .execute('sp_NhanPhong');
            return res.status(201).json({ message: 'Nhận phòng thành công (via SP)', data: spRes.recordset?.[0] });
        }

        // Fallback Transaction tuân thủ tuyệt đối các kiểm tra A2, A3, A4, B10, B11 trong 01c_hotel_check.sql
        const transaction = new sql.Transaction(pool);
        await transaction.begin();
        try {
            const reqTx = new sql.Request(transaction);
            reqTx.input('MaDat', sql.Int, parseInt(MaDat, 10));
            reqTx.input('MaPhong', sql.Int, parseInt(MaPhong, 10));

            const checkRes = await reqTx.query(`
                SELECT d.TrangThai AS TrangThaiDat, d.MaLoai AS LoaiDat,
                       p.TrangThai AS TrangThaiPhong, p.MaLoai AS LoaiPhong,
                       lp.GiaMotDem
                FROM DAT_PHONG d
                CROSS JOIN PHONG p
                INNER JOIN LOAI_PHONG lp ON lp.MaLoai = p.MaLoai
                WHERE d.MaDat = @MaDat AND p.MaPhong = @MaPhong
            `);

            if (checkRes.recordset.length === 0) {
                throw new Error('Mã đơn đặt phòng hoặc Mã phòng không tồn tại!');
            }

            const info = checkRes.recordset[0];
            if (info.TrangThaiDat !== 'Đã đặt') {
                throw new Error('Đơn đặt phòng này đã nhận hoặc đã bị hủy!');
            }
            if (info.TrangThaiPhong !== 'Trống') {
                throw new Error('Phòng được chọn hiện không ở trạng thái Trống!');
            }
            if (info.LoaiDat !== info.LoaiPhong) {
                throw new Error('Phòng được gán không khớp với Loại phòng mà khách đã đặt!');
            }

            await reqTx.query("UPDATE DAT_PHONG SET TrangThai = N'Đã nhận' WHERE MaDat = @MaDat");
            await reqTx.query("UPDATE PHONG SET TrangThai = N'Đang thuê' WHERE MaPhong = @MaPhong");

            reqTx.input('GiaThue', sql.Decimal(12, 0), info.GiaMotDem);
            const insertRes = await reqTx.query(`
                INSERT INTO PHIEU_THUE_PHONG (MaDat, MaPhong, NgayNhanThucTe, GiaThue, TrangThai)
                OUTPUT INSERTED.*
                VALUES (@MaDat, @MaPhong, GETDATE(), @GiaThue, N'Đang thuê')
            `);

            await transaction.commit();
            res.status(201).json({ message: 'Nhận phòng thành công', data: insertRes.recordset[0] });
        } catch (txErr) {
            await transaction.rollback();
            throw txErr;
        }
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.post('/api/tra-phong', async (req, res) => {
    try {
        const { MaPhieu } = req.body;
        if (!MaPhieu) {
            return res.status(400).json({ error: 'Vui lòng cung cấp MaPhieu để trả phòng!' });
        }

        const pool = await poolPromise;

        // Ưu tiên gọi Stored Procedure sp_TraPhong của Hiền nếu đã có
        const spCheck = await pool.request().query("SELECT OBJECT_ID('sp_TraPhong', 'P') AS SpId");
        if (spCheck.recordset[0].SpId) {
            const spRes = await pool.request()
                .input('MaPhieu', sql.Int, parseInt(MaPhieu, 10))
                .execute('sp_TraPhong');
            return res.json({ message: 'Trả phòng thành công (via SP)', data: spRes.recordset?.[0] });
        }

        // Fallback Transaction tuân thủ ràng buộc CK_PTP_TrangThai và A2 trong 01c_hotel_check.sql
        const transaction = new sql.Transaction(pool);
        await transaction.begin();
        try {
            const reqTx = new sql.Request(transaction);
            reqTx.input('MaPhieu', sql.Int, parseInt(MaPhieu, 10));

            const phieuRes = await reqTx.query(`
                SELECT MaPhieu, MaPhong, NgayNhanThucTe, GiaThue, TrangThai
                FROM PHIEU_THUE_PHONG
                WHERE MaPhieu = @MaPhieu
            `);

            if (phieuRes.recordset.length === 0) {
                throw new Error('Không tìm thấy phiếu thuê phòng!');
            }
            const phieu = phieuRes.recordset[0];
            if (phieu.TrangThai !== 'Đang thuê') {
                throw new Error('Phiếu thuê này đã được trả phòng trước đó!');
            }

            reqTx.input('MaPhong', sql.Int, phieu.MaPhong);
            const updatePhieu = await reqTx.query(`
                UPDATE PHIEU_THUE_PHONG
                SET NgayTraThucTe = GETDATE(), TrangThai = N'Đã trả'
                OUTPUT INSERTED.*
                WHERE MaPhieu = @MaPhieu
            `);

            await reqTx.query("UPDATE PHONG SET TrangThai = N'Trống' WHERE MaPhong = @MaPhong");

            await transaction.commit();
            res.json({ message: 'Trả phòng thành công', data: updatePhieu.recordset[0] });
        } catch (txErr) {
            await transaction.rollback();
            throw txErr;
        }
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// =====================================================================
// 6. API NHÀ HÀNG, GỌI MÓN & THANH TOÁN (Kết nối với bảng & SP của Hiền)
// =====================================================================
app.get('/api/mon-an', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT * FROM MON_AN ORDER BY MaMon DESC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: 'Bảng MON_AN chưa được tạo hoặc lỗi truy vấn: ' + err.message });
    }
});

app.post('/api/goi-mon', async (req, res) => {
    try {
        const { MaPhieu, MaMon, SoLuong } = req.body;
        if (!MaPhieu || !MaMon || !SoLuong || SoLuong <= 0) {
            return res.status(400).json({ error: 'Vui lòng truyền đủ MaPhieu, MaMon và SoLuong (> 0)!' });
        }

        const pool = await poolPromise;
        const result = await pool.request()
            .input('MaPhieu', sql.Int, parseInt(MaPhieu, 10))
            .input('MaMon', sql.Int, parseInt(MaMon, 10))
            .input('SoLuong', sql.Int, parseInt(SoLuong, 10))
            .execute('sp_GoiMon');

        res.status(201).json({ message: 'Gọi món thành công', data: result.recordset?.[0] });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.get('/api/hoa-don', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT * FROM HOA_DON ORDER BY MaHD DESC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/thanh-toan', async (req, res) => {
    try {
        const { MaHD } = req.body;
        if (!MaHD) {
            return res.status(400).json({ error: 'Vui lòng cung cấp MaHD để thanh toán!' });
        }

        const pool = await poolPromise;
        const result = await pool.request()
            .input('MaHD', sql.Int, parseInt(MaHD, 10))
            .execute('sp_ThanhToanHoaDon');

        res.json({ message: 'Thanh toán hóa đơn thành công', data: result.recordset?.[0] });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`>>> Server Backend của Khang đang chạy tại: http://localhost:${PORT}`);
});