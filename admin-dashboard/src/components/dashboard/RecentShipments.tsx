import { Eye, Edit, MoreVertical } from 'lucide-react'

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
    statusColor: 'bg-orange-500/20 text-orange-400',
    date: '2024-01-15',
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
    statusColor: 'bg-blue-500/20 text-blue-400',
    date: '2024-01-15',
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
    statusColor: 'bg-green-500/20 text-green-400',
    date: '2024-01-14',
  },
  {
    id: 'SH-0004',
    customer: 'ليلى حسن',
    service: 'شحن دولي',
    driver: 'سارة أحمد',
    from: 'بور سعيد',
    to: 'الإسكندرية',
    price: '850 ج.م',
    status: 'قيد المراجعة',
    statusColor: 'bg-cyan-500/20 text-cyan-400',
    date: '2024-01-15',
  },
  {
    id: 'SH-0005',
    customer: 'محمود سالم',
    service: 'شحن عادي',
    driver: 'خالد علي',
    from: 'الجيزة',
    to: 'القاهرة',
    price: '180 ج.م',
    status: 'ملغي',
    statusColor: 'bg-red-500/20 text-red-400',
    date: '2024-01-14',
  },
]

export default function RecentShipments() {
  return (
    <div className="card p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold text-white">آخر الشحنات</h2>
        <a href="/shipments" className="text-orange-400 hover:text-orange-300 text-sm font-medium">
          عرض الكل →
        </a>
      </div>

      {/* Table */}
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
                    <button className="p-2 hover:bg-black-700 rounded-lg transition-colors text-gray-400 hover:text-gray-200">
                      <MoreVertical className="w-4 h-4" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="mt-6 flex items-center justify-between">
        <p className="text-sm text-gray-400">
          عرض 1-5 من <span className="font-semibold">1,243</span> شحنة
        </p>
        <div className="flex gap-2">
          <button className="px-3 py-1 bg-black-800 text-gray-400 disabled:opacity-50 rounded-base text-sm hover:bg-black-700">
            السابق
          </button>
          <button className="px-3 py-1 bg-orange-500 text-white rounded-base text-sm">1</button>
          <button className="px-3 py-1 bg-black-800 text-gray-400 rounded-base text-sm hover:bg-black-700">
            2
          </button>
          <button className="px-3 py-1 bg-black-800 text-gray-400 rounded-base text-sm hover:bg-black-700">
            3
          </button>
          <button className="px-3 py-1 bg-black-800 text-gray-400 rounded-base text-sm hover:bg-black-700">
            التالي
          </button>
        </div>
      </div>
    </div>
  )
}
