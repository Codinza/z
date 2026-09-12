import { useState } from 'react'
import { Package, Truck, CheckCircle, XCircle, DollarSign } from 'lucide-react'
import StatCard from '@/components/dashboard/StatCard'
import AnalyticsChart from '@/components/dashboard/AnalyticsChart'
import ShipmentsOverview from '@/components/dashboard/ShipmentsOverview'
import LiveMap from '@/components/dashboard/LiveMap'
import RecentShipments from '@/components/dashboard/RecentShipments'

export default function Dashboard() {
  const [dateRange, setDateRange] = useState('today')

  const stats: Array<{
    label: string
    value: string
    change: string
    icon: typeof Package
    color: 'orange' | 'blue' | 'green' | 'red'
  }> = [
    {
      label: 'إجمالي الشحنات',
      value: '1,243',
      change: '+12.8%',
      icon: Package,
      color: 'orange',
    },
    {
      label: 'الشحنات الجديدة',
      value: '48',
      change: '+5.2%',
      icon: Package,
      color: 'orange',
    },
    {
      label: 'قيد التنفيذ',
      value: '32',
      change: '-2.4%',
      icon: Truck,
      color: 'blue',
    },
    {
      label: 'تم التسليم',
      value: '1,156',
      change: '+18.9%',
      icon: CheckCircle,
      color: 'green',
    },
    {
      label: 'الملغاة',
      value: '7',
      change: '-0.5%',
      icon: XCircle,
      color: 'red',
    },
    {
      label: 'إجمالي الإيرادات',
      value: '45,320 ج.م',
      change: '+24.5%',
      icon: DollarSign,
      color: 'orange',
    },
  ]

  return (
    <div className="space-y-6">
      {/* Header Section */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">مرحباً بك 👋</h1>
          <p className="text-gray-400 mt-1">إليك ملخص أداء المنصة اليوم</p>
        </div>
        <select
          value={dateRange}
          onChange={(e) => setDateRange(e.target.value)}
          className="input-field"
        >
          <option value="today">اليوم</option>
          <option value="week">هذا الأسبوع</option>
          <option value="month">هذا الشهر</option>
          <option value="custom">مخصص</option>
        </select>
      </div>

      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {stats.map((stat, index) => (
          <StatCard key={index} {...stat} />
        ))}
      </div>

      {/* Charts and Analytics */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <AnalyticsChart />
        </div>
        <div>
          <ShipmentsOverview />
        </div>
      </div>

      {/* Live Map */}
      <LiveMap />

      {/* Recent Shipments */}
      <RecentShipments />
    </div>
  )
}
