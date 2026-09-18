import { useState } from 'react'
import {
  Users,
  UserCheck,
  Clock3,
  CarFront,
  CircleDollarSign,
  ArrowUpRight,
  Truck,
  CheckCircle2,
} from 'lucide-react'
import StatCard from '@/components/dashboard/StatCard'
import AnalyticsChart from '@/components/dashboard/AnalyticsChart'
import ShipmentsOverview from '@/components/dashboard/ShipmentsOverview'
import RecentShipments from '@/components/dashboard/RecentShipments'

export default function Dashboard() {
  const [dateRange, setDateRange] = useState('today')

  const overviewStats: Array<{
    label: string
    value: string
    change: string
    icon: typeof Users
    color: 'orange' | 'blue' | 'green' | 'red'
  }> = [
    { label: 'إجمالي العملاء', value: '12,480', change: '+8.4%', icon: Users, color: 'orange' },
    { label: 'السائقين المتصلين الآن', value: '186', change: '+12', icon: UserCheck, color: 'green' },
    { label: 'إجمالي السائقين', value: '1,240', change: '+5.1%', icon: CarFront, color: 'blue' },
    { label: 'الرحلات الجارية', value: '74', change: '+6', icon: Clock3, color: 'orange' },
    { label: 'الرحلات المكتملة', value: '3,892', change: '+18.9%', icon: CheckCircle2, color: 'green' },
    { label: 'طلبات التوصيل الحالية', value: '142', change: '+9', icon: Truck, color: 'blue' },
    { label: 'الإيرادات', value: '₩ 2.4M', change: '+24.5%', icon: CircleDollarSign, color: 'orange' },
  ]

  const activeTrips = [
    { id: 'TR-1048', customer: 'أحمد محمد', driver: 'سامي ناصر', status: 'قيد التنفيذ', price: '420 ج.م' },
    { id: 'TR-1049', customer: 'سارة علي', driver: 'خالد حسن', status: 'في الطريق', price: '510 ج.م' },
    { id: 'TR-1050', customer: 'محمود سالم', driver: 'عبدالله فهد', status: 'قيد الاستلام', price: '390 ج.م' },
    { id: 'TR-1051', customer: 'ليلى نبيل', driver: 'إبراهيم ريان', status: 'جاهز', price: '280 ج.م' },
  ]

  const driverSummary = [
    { label: 'متصلون الآن', value: '186', tone: 'green' },
    { label: 'طلبات معلقة', value: '24', tone: 'orange' },
    { label: 'سائقون جدد', value: '15', tone: 'blue' },
  ]

  const deliverySummary = [
    { label: 'طلبات جديدة', value: '38', tone: 'orange' },
    { label: 'قيد التنفيذ', value: '19', tone: 'blue' },
    { label: 'مكتملة', value: '126', tone: 'green' },
  ]

  return (
    <div className="space-y-8">
      <header className="flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
        <div>
          <p className="text-sm font-medium text-orange-400 mb-2">نظرة عامة</p>
          <h1 className="text-3xl font-black text-white">لوحة التحكم</h1>
        </div>

        <div className="flex items-center gap-3">
          <button className="btn-secondary px-4 py-2 text-sm">تحديث</button>
          <select
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value)}
            className="input-field min-w-[170px]"
          >
            <option value="today">آخر 24 ساعة</option>
            <option value="week">هذا الأسبوع</option>
            <option value="month">هذا الشهر</option>
          </select>
        </div>
      </header>

      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold text-white">الإحصائيات الأساسية</h2>
          <span className="text-sm text-gray-400">آخر تحديث الآن</span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
          {overviewStats.map((stat, index) => (
            <StatCard key={index} {...stat} />
          ))}
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.5fr_0.9fr]">
        <div className="card p-5">
          <div className="flex items-center justify-between mb-5">
            <div>
              <h3 className="text-lg font-bold text-white">الرحلات الحالية</h3>
              <p className="text-sm text-gray-400 mt-1">آخر الرحلات المهمة في الوقت الحالي</p>
            </div>
            <button className="btn-secondary text-sm">عرض الكل</button>
          </div>

          <div className="space-y-3">
            {activeTrips.map((trip) => (
              <div key={trip.id} className="flex items-center justify-between gap-4 rounded-2xl border border-gray-700 bg-black-900/80 px-4 py-3">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-sm font-bold text-white">{trip.id}</span>
                    <span className="badge bg-orange-500/15 text-orange-400">{trip.status}</span>
                  </div>
                  <p className="text-sm text-gray-300">العميل: {trip.customer}</p>
                  <p className="text-xs text-gray-400">السائق: {trip.driver}</p>
                </div>

                <div className="text-left">
                  <p className="text-xs text-gray-400">السعر</p>
                  <p className="text-base font-bold text-white">{trip.price}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-6">
          <div className="card p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold text-white">السائقون</h3>
              <button className="text-sm text-orange-400">إدارة السائقين</button>
            </div>

            <div className="space-y-3">
              {driverSummary.map((item) => (
                <div key={item.label} className="flex items-center justify-between rounded-xl border border-gray-700 bg-black-900/70 px-3 py-2.5">
                  <span className="text-sm text-gray-300">{item.label}</span>
                  <span className={`text-lg font-bold ${item.tone === 'green' ? 'text-green-400' : item.tone === 'orange' ? 'text-orange-400' : 'text-blue-400'}`}>
                    {item.value}
                  </span>
                </div>
              ))}
            </div>
          </div>

          <div className="card p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold text-white">التوصيل والشحن</h3>
              <button className="text-sm text-orange-400">عرض الطلبات</button>
            </div>

            <div className="space-y-3">
              {deliverySummary.map((item) => (
                <div key={item.label} className="flex items-center justify-between rounded-xl border border-gray-700 bg-black-900/70 px-3 py-2.5">
                  <span className="text-sm text-gray-300">{item.label}</span>
                  <span className={`text-lg font-bold ${item.tone === 'green' ? 'text-green-400' : item.tone === 'orange' ? 'text-orange-400' : 'text-blue-400'}`}>
                    {item.value}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.5fr_0.9fr]">
        <div className="card p-5">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-lg font-bold text-white">إحصائيات الأداء</h3>
            <span className="text-sm text-gray-400">الأسبوع الحالي</span>
          </div>
          <AnalyticsChart />
        </div>

        <div className="card p-5">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-lg font-bold text-white">مؤشرات التشغيل</h3>
            <ArrowUpRight className="w-4 h-4 text-orange-400" />
          </div>
          <ShipmentsOverview />
        </div>
      </section>

      <section className="card p-5">
        <div className="flex items-center justify-between mb-5">
          <div>
            <h3 className="text-lg font-bold text-white">آخر النشاطات</h3>
            <p className="text-sm text-gray-400 mt-1">أحدث الأنشطة التشغيلية داخل المنصة</p>
          </div>
          <button className="btn-secondary text-sm">عرض كل النشاطات</button>
        </div>

        <RecentShipments />
      </section>
    </div>
  )
}
