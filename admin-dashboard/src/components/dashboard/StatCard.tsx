import { TrendingUp, TrendingDown } from 'lucide-react'
import { LucideIcon } from 'lucide-react'

interface StatCardProps {
  label: string
  value: string
  change: string
  icon: LucideIcon
  color: 'orange' | 'blue' | 'green' | 'red'
}

const colorMap = {
  orange: 'bg-orange-500/10 text-orange-400',
  blue: 'bg-blue-500/10 text-blue-400',
  green: 'bg-green-500/10 text-green-400',
  red: 'bg-red-500/10 text-red-400',
}

export default function StatCard({ label, value, change, icon: Icon, color }: StatCardProps) {
  const isPositive = change.startsWith('+')

  return (
    <div className="card p-5 transition-all duration-200 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-orange-500/5">
      <div className="flex items-start justify-between mb-4">
        <div className={`p-3 rounded-xl ${colorMap[color]}`}>
          <Icon className="w-5 h-5" />
        </div>
        <div className={`flex items-center gap-1 text-xs font-semibold ${isPositive ? 'text-green-400' : 'text-red-400'}`}>
          {isPositive ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
          {change}
        </div>
      </div>

      <p className="text-sm text-gray-400 mb-2">{label}</p>
      <p className="text-2xl font-black text-white leading-none">{value}</p>
    </div>
  )
}
