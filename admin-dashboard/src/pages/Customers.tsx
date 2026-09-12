import { Plus } from 'lucide-react'

const customers = [
  { id: 1, name: 'أحمد محمد', phone: '01001234567', orders: 12, spent: '3,450 ج.م', lastOrder: '2024-01-15' },
  { id: 2, name: 'فاطمة علي', phone: '01112345678', orders: 8, spent: '2,100 ج.م', lastOrder: '2024-01-14' },
  { id: 3, name: 'عمر سيد', phone: '01223456789', orders: 24, spent: '6,800 ج.م', lastOrder: '2024-01-15' },
]

export default function Customers() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">إدارة العملاء</h1>
          <p className="text-gray-400 mt-1">إدارة جميع العملاء والحسابات</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors font-medium">
          <Plus className="w-5 h-5" />
          عميل جديد
        </button>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-orange-400">1,243</p>
          <p className="text-gray-400 text-sm mt-1">إجمالي العملاء</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-blue-400">156</p>
          <p className="text-gray-400 text-sm mt-1">نشطين اليوم</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-green-400">2.1M</p>
          <p className="text-gray-400 text-sm mt-1">إجمالي الإنفاق</p>
        </div>
      </div>
      <div className="card p-6 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-gray-700">
              <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الاسم</th>
              <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الهاتف</th>
              <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الطلبات</th>
              <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الإنفاق</th>
              <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">آخر طلب</th>
            </tr>
          </thead>
          <tbody>
            {customers.map((customer) => (
              <tr key={customer.id} className="border-b border-gray-700 hover:bg-black-800">
                <td className="px-4 py-3 text-sm font-medium text-white">{customer.name}</td>
                <td className="px-4 py-3 text-sm text-gray-300">{customer.phone}</td>
                <td className="px-4 py-3 text-sm text-gray-300">{customer.orders}</td>
                <td className="px-4 py-3 text-sm text-orange-400 font-semibold">{customer.spent}</td>
                <td className="px-4 py-3 text-sm text-gray-300">{customer.lastOrder}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
