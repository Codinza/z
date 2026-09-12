import { useState } from 'react'
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

const data = [
  { date: '1 يناير', shipments: 400, revenue: 2400 },
  { date: '2 يناير', shipments: 480, revenue: 2210 },
  { date: '3 يناير', shipments: 520, revenue: 2290 },
  { date: '4 يناير', shipments: 490, revenue: 2000 },
  { date: '5 يناير', shipments: 560, revenue: 2181 },
  { date: '6 يناير', shipments: 630, revenue: 2500 },
  { date: '7 يناير', shipments: 580, revenue: 2100 },
]

export default function AnalyticsChart() {
  const [chartType, setChartType] = useState<'shipments' | 'revenue'>('shipments')

  return (
    <div className="card p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold text-white">الشحنات والإيرادات</h2>
        <div className="flex gap-2">
          <button
            onClick={() => setChartType('shipments')}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              chartType === 'shipments'
                ? 'bg-orange-500 text-white'
                : 'bg-black-800 text-gray-300 hover:bg-black-700'
            }`}
          >
            الشحنات
          </button>
          <button
            onClick={() => setChartType('revenue')}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              chartType === 'revenue'
                ? 'bg-orange-500 text-white'
                : 'bg-black-800 text-gray-300 hover:bg-black-700'
            }`}
          >
            الإيرادات
          </button>
        </div>
      </div>

      <div className="flex gap-2 mb-6">
        {['7 أيام', '30 يوم', '3 شهور', 'سنة'].map((period) => (
          <button
            key={period}
            className="px-3 py-1 bg-black-800 text-gray-400 hover:text-gray-200 rounded-base text-xs font-medium transition-colors"
          >
            {period}
          </button>
        ))}
      </div>

      <ResponsiveContainer width="100%" height={300}>
        {chartType === 'shipments' ? (
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#333" />
            <XAxis dataKey="date" stroke="#666" />
            <YAxis stroke="#666" />
            <Tooltip
              contentStyle={{
                backgroundColor: '#1a1a1a',
                border: '1px solid #444',
                borderRadius: '8px',
              }}
            />
            <Bar dataKey="shipments" fill="#f97316" radius={[8, 8, 0, 0]} />
          </BarChart>
        ) : (
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#333" />
            <XAxis dataKey="date" stroke="#666" />
            <YAxis stroke="#666" />
            <Tooltip
              contentStyle={{
                backgroundColor: '#1a1a1a',
                border: '1px solid #444',
                borderRadius: '8px',
              }}
            />
            <Line
              type="monotone"
              dataKey="revenue"
              stroke="#f97316"
              strokeWidth={2}
              dot={{ fill: '#f97316', r: 4 }}
            />
          </LineChart>
        )}
      </ResponsiveContainer>
    </div>
  )
}
