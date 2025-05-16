import { useEffect, useState } from 'react'; // 导入 React 的两个 Hook，用于状态管理和副作用处理
import axios from 'axios'; // 导入 axios，用于发送 HTTP 请求

function App() {
  // address: 输入框中的地址（本例未用到）
  // connectedAddress: 当前连接的钱包地址
  // transfers: 查询到的转账记录数组
  const [address, setAddress] = useState('');
  const [connectedAddress, setConnectedAddress] = useState('');
  const [transfers, setTransfers] = useState([]);

  // 连接钱包的函数
  const connectWallet = async () => {
    if (!window.ethereum) {
      alert('请先安装 MetaMask');
      return;
    }

    const accounts = await window.ethereum.request({ method: 'eth_accounts' });
    if (accounts.length > 0) {
      setConnectedAddress(accounts[0]);
      console.log('已连接账户：', accounts[0]);
      return;
    }

    try {
      const newAccounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
      setConnectedAddress(newAccounts[0]);
      console.log('请求连接成功：', newAccounts[0]);
    } catch (err) {
      console.error('连接失败', err);
      alert('连接失败');
    }
  };


  // 当 connectedAddress 变化时，自动查询该地址的转账记录
  useEffect(() => {
    if (!connectedAddress) return; // 没有连接钱包时不查询
    const fetchTransfers = async () => {
      // 调用后端接口，获取转账记录
      const res = await axios.get(`http://localhost:3000/transfers?address=${connectedAddress}`);
      setTransfers(res.data); // 保存查询结果到状态
    };
    fetchTransfers();
  }, [connectedAddress]); // 依赖 connectedAddress，变化时重新执行

  return (
    <div style={{ padding: '2rem' }}>
      <h2>ERC20 转账记录查看器</h2>
      {/* 连接钱包按钮 */}
      <button onClick={connectWallet}>连接钱包</button>
      {/* 显示当前连接的钱包地址 */}
      {connectedAddress
        ? <p style={{ color: 'green' }}>✅ 当前已连接：{connectedAddress}</p>
        : <p style={{ color: 'red' }}>⚠️ 钱包未连接</p>
      }

      {/* 转账记录表格 */}
      <table border="1" cellPadding="6" style={{ marginTop: '20px' }}>
        <thead>
          <tr>
            <th>区块</th>
            <th>交易哈希</th>
            <th>From</th>
            <th>To</th>
            <th>金额</th>
          </tr>
        </thead>
        <tbody>
          {/* 遍历转账记录数组，渲染每一行 */}
          {transfers.map((tx) => (
            <tr key={tx.tx_hash}>
              <td>{tx.block_number}</td>
              {/* 只显示交易哈希前10位，鼠标悬停显示完整哈希 */}
              <td title={tx.tx_hash}>{tx.tx_hash.slice(0, 10)}...</td>
              {/* 如果 from 地址等于当前钱包地址，显示为红色 */}
              <td style={{ color: tx.from_address.toLowerCase() === connectedAddress.toLowerCase() ? 'red' : 'black' }}>
                {tx.from_address}
              </td>
              {/* 如果 to 地址等于当前钱包地址，显示为绿色 */}
              <td style={{ color: tx.to_address.toLowerCase() === connectedAddress.toLowerCase() ? 'green' : 'black' }}>
                {tx.to_address}
              </td>
              <td>{tx.amount}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default App; // 导出 App 组件
