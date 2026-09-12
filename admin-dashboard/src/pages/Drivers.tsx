import { Plus, MoreVertical } from 'lucide-react'

const drivers = [
  {
    id: 1,
    name: 'علي سالم',
    phone: '01001234567',
    car: 'تويوتا كامري',
    carNumber: '778',
    status: 'متصل',
    statusColor: 'text-green-400',
    orders: 45,
    rating: 4.8,
    earnings: '12,500 ج.م',
  },
  {
    id: 2,
    name: 'محمود حسن',
    phone: '01112345678',
    car: 'هيونداي إيلانترا',
    carNumber: '234',
    status: 'في مهمة',
    statusColor: 'text-orange-400',
    orders: 38,
    rating: 4.6,
    earnings: '11,200 ج.م',
  },
  {
    id: 3,
    name: 'أحمد محمد',
    phone: '01223456789',
    car: 'نيسان ألتيما',
    carNumber: '567',
    status: 'غير متصل',
    statusColor: 'text-gray-400',
    orders: 52,
    rating: 4.9,
    earnings: '14,800 ج.م',
  },
]

export default function Drivers() {
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">إدارة السائقين</h1>
          <p className="text-gray-400 mt-1">إدارة وتتبع جميع السائقين</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors font-medium">
          <Plus className="w-5 h-5" />
          سائق جديد
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-orange-400">23</p>
          <p className="text-gray-400 text-sm mt-1">متصل الآن</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-gray-300">8</p>
          <p className="text-gray-400 text-sm mt-1">في مهمة</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-gray-300">12</p>
          <p className="text-gray-400 text-sm mt-1">غير متصل</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-green-400">198,520</p>
          <p className="text-gray-400 text-sm mt-1">إجمالي الأرباح</p>
        </div>
      </div>

      {/* Drivers Table */}
      <div className="card p-6 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-700">
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">اسم السائق</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الهاتف</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">السيارة</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الرقم</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الحالة</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الطلبات</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">التقييم</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الأرباح</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الإجراء</th>
              </tr>
            </thead>
            <tbody>
              {drivers.map((driver) => (
                <tr
                  key={driver.id}
                  className="border-b border-gray-700 hover:bg-black-800 transition-colors"
                >
                  <td className="px-4 py-3 text-sm font-medium text-white">{driver.name}</td>
                  <td className="px-4 py-3 text-sm text-gray-300">{driver.phone}</td>
                  <td className="px-4 py-3 text-sm text-gray-300">{driver.car}</td>
                  <td className="px-4 py-3 text-sm text-gray-300">{driver.carNumber}</td>
                  <td className="px-4 py-3">
                    <span className={`text-sm font-medium ${driver.statusColor}`}>{driver.status}</span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-300">{driver.orders}</td>
                  <td className="px-4 py-3 text-sm">
                    <span className="text-yellow-400">★ {driver.rating}</span>
                  </td>
                  <td className="px-4 py-3 text-sm font-semibold text-white">{driver.earnings}</td>
                  <td className="px-4 py-3 text-sm">
                    <button className="p-2 hover:bg-black-700 rounded-lg transition-colors text-gray-400 hover:text-gray-200">
                      <MoreVertical className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
