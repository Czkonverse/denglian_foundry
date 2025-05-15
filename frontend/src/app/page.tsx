'use client';

import React from 'react';
import { useEffect, useState } from 'react';
import { useAccount } from 'wagmi';
import { ConnectKitButton } from 'connectkit';
import axios from 'axios';
import { format } from 'date-fns';

interface Transfer {
  id: number;
  from: string;
  to: string;
  amount: string;
  tokenAddress: string;
  txHash: string;
  blockNumber: number;
  timestamp: string;
}

export default function Home() {
  const { address, isConnected } = useAccount();
  const [transfers, setTransfers] = useState<Transfer[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const fetchTransfers = async () => {
      if (!isConnected || !address) return;
      
      setLoading(true);
      try {
        const response = await axios.get(`http://localhost:3001/api/mock-transfers/${address}`);
        setTransfers(response.data);
      } catch (error) {
        console.error('Error fetching transfers:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchTransfers();
  }, [address, isConnected]);

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-gray-100 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center">
            <h2 className="text-3xl font-extrabold text-gray-900 mb-8">
              Please connect your wallet
            </h2>
            <ConnectKitButton />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-8">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-3xl font-extrabold text-gray-900">
              Your Token Transfers
            </h2>
            <ConnectKitButton />
          </div>
          <p className="mt-2 text-gray-600">
            Connected Address: {address}
          </p>
        </div>

        {loading ? (
          <div className="text-center">Loading...</div>
        ) : (
          <div className="bg-white shadow overflow-hidden sm:rounded-lg">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Type
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Amount
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    From/To
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {transfers.map((transfer) => (
                  <tr key={transfer.id}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        transfer.from.toLowerCase() === address?.toLowerCase()
                          ? 'bg-red-100 text-red-800'
                          : 'bg-green-100 text-green-800'
                      }`}>
                        {transfer.from.toLowerCase() === address?.toLowerCase() ? 'Sent' : 'Received'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {transfer.amount}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {transfer.from.toLowerCase() === address?.toLowerCase()
                        ? `To: ${transfer.to.slice(0, 6)}...${transfer.to.slice(-4)}`
                        : `From: ${transfer.from.slice(0, 6)}...${transfer.from.slice(-4)}`}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {format(new Date(transfer.timestamp), 'MMM dd, yyyy HH:mm')}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
} 