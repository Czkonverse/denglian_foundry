require('dotenv').config(); // 加载 .env 文件中的环境变量

const express = require('express'); // 导入 express 框架，用于搭建 Web 服务器
const cors = require('cors'); // 导入 cors 中间件，允许跨域请求
const sqlite3 = require('sqlite3').verbose(); // 导入 sqlite3 数据库模块

const app = express(); // 创建一个 express 应用实例
const port = 3000; // 设置服务器监听的端口号

const db = new sqlite3.Database('./transfers.db'); // 连接本地的 transfers.db 数据库文件
app.use(cors()); // 启用 CORS，允许前端页面跨域访问本服务

// 定义一个 GET 接口 /transfers，用于根据地址查询转账记录
app.get('/transfers', (req, res) => {
    const address = req.query.address?.toLowerCase(); // 获取请求参数中的 address，并转为小写
    if (!address) {
        // 如果没有传 address 参数，返回 400 错误
        return res.status(400).json({ error: 'address parameter is required' });
    }

    // SQL 查询语句：查找 from_address 或 to_address 等于指定地址的转账记录，按区块号倒序排列
    const sql = `
    SELECT block_number, tx_hash, from_address, to_address, amount 
    FROM transfers 
    WHERE lower(from_address) = ? OR lower(to_address) = ?
    ORDER BY block_number DESC
  `;

    // 执行 SQL 查询，参数为 address（查 from 和 to 两个字段）
    db.all(sql, [address, address], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message }); // 查询出错，返回 500 错误
        return res.json(rows); // 查询成功，返回所有结果（数组）
    });
});

// 启动服务器，监听指定端口
app.listen(port, () => {
    console.log(`📡 REST API running at http://localhost:${port}`);
});
