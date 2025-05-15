const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./transfers.db');

db.serialize(() => {
    db.run(`
    CREATE TABLE IF NOT EXISTS transfers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tx_hash TEXT UNIQUE,
      block_number INTEGER,
      from_address TEXT,
      to_address TEXT,
      amount TEXT,
      token_address TEXT
    )
  `);
});

function saveTransfer({ txHash, blockNumber, from, to, amount, token }) {
    const stmt = db.prepare(`
    INSERT OR IGNORE INTO transfers 
    (tx_hash, block_number, from_address, to_address, amount, token_address) 
    VALUES (?, ?, ?, ?, ?, ?)
  `);
    stmt.run(txHash, blockNumber, from, to, amount.toString(), token);
    stmt.finalize();
}

module.exports = { saveTransfer };
