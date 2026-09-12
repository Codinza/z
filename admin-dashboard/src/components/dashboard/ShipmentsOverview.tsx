import { PieChart, Pie, Cell, ResponsiveContainer } from 'recharts'

const statusData = [
  { name: 'جديدة', value: 48, color: '#f97316' },
  { name: 'قيد المراجعة', value: 32, color: '#3b82f6' },
  { name: 'قيد التنفيذ', value: 156, color: '#06b6d4' },
  { name: 'تم التسليم', value: 1156, color: '#10b981' },
  { name: 'ملغاة', value: 7, color: '#ef4444' },
]

export default function ShipmentsOverview() {
  return (
    <div className="card p-6">
      <h2 className="text-xl font-semibold text-white mb-6">توزيع الحالات</h2>

      <ResponsiveContainer width="100%" height={250}>
        <PieChart>
          <Pie
            data={statusData}
            cx="50%"
            cy="50%"
            innerRadius={60}
            outerRadius={100}
            paddingAngle={2}
            dataKey="value"
          >
            {statusData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.color} />
            ))}
          </Pie>
        </PieChart>
      </ResponsiveContainer>

      <div className="mt-6 space-y-3">
        {statusData.map((status, index) => (
          <div key={index} className="flex items-center justify-between text-sm">
            <div className="flex items-center gap-2">
              <div
                className="w-3 h-3 rounded-full"
                style={{ backgroundColor: status.color }}
              ></div>
              <span className="text-gray-300">{status.name}</span>
            </div>
            <span className="font-semibold text-white">{status.value}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
