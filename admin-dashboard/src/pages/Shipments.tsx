import { useState } from 'react'
import { Search, Filter, Plus, Eye, Edit, Trash2 } from 'lucide-react'

const shipments = [
  {
    id: 'SH-0001',
    customer: 'أحمد محمد',
    service: 'شحن عادي',
    driver: 'علي سالم',
    from: 'القاهرة',
    to: 'الجيزة',
    price: '250 ج.م',
    status: 'جديد',
    statusColor: 'badge-pending',
  },
  {
    id: 'SH-0002',
    customer: 'فاطمة علي',
    service: 'شحن عاجل',
    driver: 'محمود حسن',
    from: 'الإسكندرية',
    to: 'القاهرة',
    price: '450 ج.م',
    status: 'قيد التنفيذ',
    statusColor: 'badge-in-progress',
  },
  {
    id: 'SH-0003',
    customer: 'عمر سيد',
    service: 'شحن عادي',
    driver: 'أحمد محمد',
    from: 'المنصورة',
    to: 'القاهرة',
    price: '320 ج.م',
    status: 'تم التسليم',
    statusColor: 'badge-success',
  },
]

export default function Shipments() {
  const [searchTerm, setSearchTerm] = useState('')

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">الشحنات</h1>
          <p className="text-gray-400 mt-1">إدارة جميع الشحنات والطلبات</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors font-medium">
          <Plus className="w-5 h-5" />
          شحنة جديدة
        </button>
      </div>

      {/* Filters and Search */}
      <div className="card p-4">
        <div className="flex gap-4 flex-wrap">
          <div className="flex-1 min-w-64">
            <div className="relative">
              <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                placeholder="ابحث عن رقم طلب..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="input-field w-full pr-10"
              />
            </div>
          </div>
          <select className="input-field">
            <option>جميع الحالات</option>
            <option>جديد</option>
            <option>قيد التنفيذ</option>
            <option>تم التسليم</option>
          </select>
          <select className="input-field">
            <option>جميع الخدمات</option>
            <option>شحن عادي</option>
            <option>شحن عاجل</option>
            <option>شحن دولي</option>
          </select>
          <button className="flex items-center gap-2 px-4 py-2 bg-black-800 text-gray-300 hover:bg-black-700 rounded-lg transition-colors">
            <Filter className="w-4 h-4" />
            تصفية متقدمة
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="card p-6 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-700">
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">رقم الطلب</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">العميل</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الخدمة</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">السائق</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">من → إلى</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">السعر</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الحالة</th>
                <th className="px-4 py-3 text-right text-sm font-semibold text-gray-300">الإجراء</th>
              </tr>
            </thead>
            <tbody>
              {shipments.map((shipment) => (
                <tr
                  key={shipment.id}
                  className="border-b border-gray-700 hover:bg-black-800 transition-colors"
                >
                  <td className="px-4 py-3 text-sm font-medium text-white">{shipment.id}</td>
                  <td className="px-4 py-3 text-sm text-gray-300">{shipment.customer}</td>
                  <td className="px-4 py-3 text-sm text-gray-300">{shipment.service}</td>
                  <td className="px-4 py-3 text-sm text-gray-300">{shipment.driver}</td>
                  <td className="px-4 py-3 text-sm text-gray-300">
                    {shipment.from} ← {shipment.to}
                  </td>
                  <td className="px-4 py-3 text-sm font-semibold text-white">{shipment.price}</td>
                  <td className="px-4 py-3">
                    <span className={`badge ${shipment.statusColor}`}>{shipment.status}</span>
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <div className="flex items-center gap-2">
                      <button className="p-2 hover:bg-black-700 rounded-lg transition-colors text-gray-400 hover:text-gray-200">
                        <Eye className="w-4 h-4" />
                      </button>
                      <button className="p-2 hover:bg-black-700 rounded-lg transition-colors text-gray-400 hover:text-gray-200">
                        <Edit className="w-4 h-4" />
                      </button>
                      <button className="p-2 hover:bg-black-700 rounded-lg transition-colors text-gray-400 hover:text-red-400">
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
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
