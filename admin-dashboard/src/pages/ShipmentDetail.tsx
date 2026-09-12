import { useParams } from 'react-router-dom'
import { DollarSign, Calendar } from 'lucide-react'

export default function ShipmentDetail() {
  const { id } = useParams()

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">تفاصيل الشحنة {id}</h1>
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="card p-6">
            <h2 className="text-xl font-semibold text-white mb-4">معلومات الشحنة</h2>
            <div className="space-y-4">
              <div className="flex justify-between">
                <span className="text-gray-400">حالة الطلب:</span>
                <span className="badge badge-pending">جديد</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">الخدمة:</span>
                <span className="text-white">شحن عادي</span>
              </div>
            </div>
          </div>
        </div>
        <div className="card p-6">
          <h2 className="text-xl font-semibold text-white mb-4">ملخص</h2>
          <div className="space-y-3">
            <div className="flex items-center gap-2 text-gray-300">
              <DollarSign className="w-5 h-5 text-orange-400" />
              <span>250 ج.م</span>
            </div>
            <div className="flex items-center gap-2 text-gray-300">
              <Calendar className="w-5 h-5 text-blue-400" />
              <span>2024-01-15</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
