// =====================================================================
// FILE: backend/restaurant.routes.js  (đề nghị Khang thêm vào backend)
// Viết khớp 02_restaurant_tables.sql và 03_logic.sql của Hiền.
//
// CÁCH GẮN: trong server.js, trước app.listen(...) thêm 1 dòng:
//     require('./restaurant.routes')(app);
//
// API bổ sung:
//   POST   /api/mon-an            thêm món
//   PUT    /api/mon-an/:id        sửa món (gồm cập nhật giá)
//   DELETE /api/mon-an/:id        xóa món
//   POST   /api/goi-mon-nhieu     gọi nhiều món (sp_GoiMon cần @MaNV + bảng @Mon)
//   POST   /api/tra-phong-hd      trả phòng (sp_TraPhong cần @MaNV, trả @MaHD)
//   GET    /api/hoa-don/tong-hop  tiền phòng + tiền món + hóa đơn mỗi phiếu thuê
//   GET    /api/hoa-don/phieu/:maPhieu/chi-tiet  các món đã gọi của phiếu
// =====================================================================
const { sql, poolPromise } = require('./db');

const TT_MON = ['Còn bán', 'Ngừng bán'];

// MaNV lấy từ phiên đăng nhập. Nếu giao diện chưa gửi thì chọn tạm nhân viên hợp lệ (chỉ để demo).
async function resolveStaff(pool, maNV, roleOnly) {
    if (maNV && !isNaN(Number(maNV))) return Number(maNV);
    const r = await pool.request().query(`
        SELECT TOP 1 MaNV FROM dbo.NHAN_VIEN
        WHERE TrangThai = 1 ${roleOnly ? "AND VaiTro IN (N'Quản lý', N'Lễ tân')" : ''}
        ORDER BY MaNV`);
    if (r.recordset.length === 0) throw new Error('Không có nhân viên hợp lệ để thực hiện thao tác!');
    return r.recordset[0].MaNV;
}

function checkDish(b) {
    if (!b.TenMon || !String(b.TenMon).trim()) return 'Tên món không được để trống!';
    if (!b.LoaiMon || !String(b.LoaiMon).trim()) return 'Phân loại món không được để trống!';
    if (b.DonGia === undefined || isNaN(Number(b.DonGia)) || Number(b.DonGia) <= 0) return 'Đơn giá phải lớn hơn 0!';
    if (b.TrangThai !== undefined && !TT_MON.includes(b.TrangThai)) return "Trạng thái món chỉ nhận 'Còn bán' hoặc 'Ngừng bán'!";
    return null;
}
const bindDish = (r, b) => r
    .input('Ten', sql.NVarChar(100), String(b.TenMon).trim())
    .input('Loai', sql.NVarChar(50), String(b.LoaiMon).trim())
    .input('Gia', sql.Decimal(12, 0), Number(b.DonGia))
    .input('TT', sql.NVarChar(20), b.TrangThai || 'Còn bán');
const dishError = (e) => /UNIQUE|duplicate/i.test(e.message) ? 'Tên món này đã tồn tại!' : e.message;

module.exports = function (app) {
    // ------------------------------ THỰC ĐƠN ------------------------------
    app.post('/api/mon-an', async (req, res) => {
        try {
            const err = checkDish(req.body);
            if (err) return res.status(400).json({ error: err });
            const pool = await poolPromise;
            const r = await bindDish(pool.request(), req.body).query(`
                INSERT INTO dbo.MON_AN (TenMon, DonGia, LoaiMon, TrangThai)
                OUTPUT INSERTED.*
                VALUES (@Ten, @Gia, @Loai, @TT)`);
            res.status(201).json(r.recordset[0]);
        } catch (e) { res.status(400).json({ error: dishError(e) }); }
    });

    app.put('/api/mon-an/:id', async (req, res) => {
        try {
            const err = checkDish(req.body);
            if (err) return res.status(400).json({ error: err });
            const pool = await poolPromise;
            const r = await bindDish(pool.request(), req.body)
                .input('Id', sql.Int, parseInt(req.params.id, 10))
                .query(`
                UPDATE dbo.MON_AN
                SET TenMon = @Ten, DonGia = @Gia, LoaiMon = @Loai, TrangThai = @TT
                OUTPUT INSERTED.*
                WHERE MaMon = @Id`);
            if (r.recordset.length === 0) return res.status(404).json({ error: 'Không tìm thấy món ăn!' });
            res.json(r.recordset[0]);
        } catch (e) { res.status(400).json({ error: dishError(e) }); }
    });

    app.delete('/api/mon-an/:id', async (req, res) => {
        try {
            const pool = await poolPromise;
            const r = await pool.request()
                .input('Id', sql.Int, parseInt(req.params.id, 10))
                .query('DELETE FROM dbo.MON_AN WHERE MaMon = @Id');
            if (r.rowsAffected[0] === 0) return res.status(404).json({ error: 'Không tìm thấy món ăn!' });
            res.json({ message: 'Xóa món ăn thành công' });
        } catch (e) {
            res.status(400).json({ error: 'Không thể xóa món đã từng được gọi. Hãy chuyển sang "Tạm hết món" (Ngừng bán).' });
        }
    });

    // ------------------------------ GỌI MÓN ------------------------------
    // Body: { MaPhieu, MaNV?, Mon: [{ MaMon, SoLuong }, ...] }
    app.post('/api/goi-mon-nhieu', async (req, res) => {
        try {
            const { MaPhieu, MaNV, Mon } = req.body;
            if (!MaPhieu || !Array.isArray(Mon) || Mon.length === 0) {
                return res.status(400).json({ error: 'Vui lòng truyền MaPhieu và danh sách món!' });
            }
            const merged = new Map();                       // mỗi MaMon chỉ một dòng (PK của DanhSachMon)
            for (const m of Mon) {
                const id = parseInt(m.MaMon, 10), q = parseInt(m.SoLuong, 10);
                if (!id || !(q > 0)) return res.status(400).json({ error: 'Mã món hoặc số lượng không hợp lệ!' });
                merged.set(id, (merged.get(id) || 0) + q);
            }
            const pool = await poolPromise;
            const tvp = new sql.Table('dbo.DanhSachMon');
            tvp.columns.add('MaMon', sql.Int);
            tvp.columns.add('SoLuong', sql.Int);
            merged.forEach((q, id) => tvp.rows.add(id, q));

            const nv = await resolveStaff(pool, MaNV, false);
            const r = await pool.request()
                .input('MaPhieu', sql.Int, parseInt(MaPhieu, 10))
                .input('MaNV', sql.Int, nv)
                .input('Mon', tvp)
                .output('MaGoiMon', sql.Int)
                .execute('dbo.sp_GoiMon');
            res.status(201).json({ message: 'Gọi món thành công', MaGoiMon: r.output.MaGoiMon });
        } catch (e) { res.status(400).json({ error: e.message }); }
    });

    // ------------------------------ TRẢ PHÒNG ------------------------------
    // Body: { MaPhieu, MaNV? }  → sp_TraPhong tự lập hóa đơn "Chưa thanh toán"
    app.post('/api/tra-phong-hd', async (req, res) => {
        try {
            const { MaPhieu, MaNV } = req.body;
            if (!MaPhieu) return res.status(400).json({ error: 'Vui lòng cung cấp MaPhieu để trả phòng!' });
            const pool = await poolPromise;
            const nv = await resolveStaff(pool, MaNV, true);   // SP chỉ cho Quản lý / Lễ tân
            const r = await pool.request()
                .input('MaPhieu', sql.Int, parseInt(MaPhieu, 10))
                .input('MaNV', sql.Int, nv)
                .output('MaHD', sql.Int)
                .execute('dbo.sp_TraPhong');
            res.json({ message: 'Trả phòng thành công', MaHD: r.output.MaHD });
        } catch (e) { res.status(400).json({ error: e.message }); }
    });

    // ------------------------------ HÓA ĐƠN ------------------------------
    // Mỗi phiếu thuê: tiền phòng (đã chốt nếu có hóa đơn, tạm tính nếu đang thuê) + tiền món + hóa đơn
    app.get('/api/hoa-don/tong-hop', async (req, res) => {
        try {
            const pool = await poolPromise;
            const r = await pool.request().query(`
                SELECT t.MaPhieu, kh.HoTen, ph.SoPhong, lp.TenLoai,
                       t.NgayNhanThucTe, t.NgayTraThucTe, t.TrangThai AS TrangThaiPhieu,
                       CASE WHEN h.MaHD IS NOT NULL THEN ISNULL(ct.TienPhong, 0)
                            ELSE CONVERT(DECIMAL(19,0), t.GiaThue) *
                                 CASE WHEN DATEDIFF(DAY, t.NgayNhanThucTe, GETDATE()) < 1 THEN 1
                                      ELSE DATEDIFF(DAY, t.NgayNhanThucTe, GETDATE()) END
                       END AS TienPhong,
                       ISNULL(f.TienNhaHang, 0) AS TienNhaHang,
                       ISNULL(f.SoLuotGoi, 0)   AS SoLuotGoi,
                       h.MaHD, h.TrangThai AS TrangThaiHD
                FROM dbo.PHIEU_THUE_PHONG t
                INNER JOIN dbo.DAT_PHONG d   ON d.MaDat    = t.MaDat
                INNER JOIN dbo.KHACH_HANG kh ON kh.MaKH    = d.MaKH
                INNER JOIN dbo.PHONG ph      ON ph.MaPhong = t.MaPhong
                INNER JOIN dbo.LOAI_PHONG lp ON lp.MaLoai  = ph.MaLoai
                LEFT JOIN  dbo.HOA_DON h     ON h.MaPhieu  = t.MaPhieu
                OUTER APPLY (
                    SELECT SUM(c.ThanhTien) AS TienPhong
                    FROM dbo.CHI_TIET_HOA_DON c WHERE c.MaHD = h.MaHD AND c.LoaiDong = N'Phòng'
                ) ct
                OUTER APPLY (
                    SELECT SUM(CONVERT(DECIMAL(19,0), x.SoLuong) * x.DonGia) AS TienNhaHang,
                           COUNT(DISTINCT g.MaGoiMon) AS SoLuotGoi
                    FROM dbo.PHIEU_GOI_MON g
                    INNER JOIN dbo.CHI_TIET_GOI_MON x ON x.MaGoiMon = g.MaGoiMon
                    WHERE g.MaPhieu = t.MaPhieu
                ) f
                ORDER BY t.MaPhieu DESC`);
            res.json(r.recordset);
        } catch (e) { res.status(500).json({ error: e.message }); }
    });

    // Các món đã gọi của một phiếu thuê (giá là giá đã chụp lúc gọi)
    app.get('/api/hoa-don/phieu/:maPhieu/chi-tiet', async (req, res) => {
        try {
            const pool = await poolPromise;
            const r = await pool.request()
                .input('MaPhieu', sql.Int, parseInt(req.params.maPhieu, 10))
                .query(`
                SELECT g.NgayGoi, m.TenMon, c.SoLuong, c.DonGia,
                       CONVERT(DECIMAL(19,0), c.SoLuong) * c.DonGia AS ThanhTien
                FROM dbo.PHIEU_GOI_MON g
                INNER JOIN dbo.CHI_TIET_GOI_MON c ON c.MaGoiMon = g.MaGoiMon
                INNER JOIN dbo.MON_AN m ON m.MaMon = c.MaMon
                WHERE g.MaPhieu = @MaPhieu
                ORDER BY g.NgayGoi, g.MaGoiMon`);
            res.json(r.recordset);
        } catch (e) { res.status(500).json({ error: e.message }); }
    });
};
