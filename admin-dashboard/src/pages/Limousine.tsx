import { Plus } from 'lucide-react'

export default function Limousine() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">إدارة الليموزين</h1>
          <p className="text-gray-400 mt-1">إدارة طلبات وحجوزات الليموزين</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors font-medium">
          <Plus className="w-5 h-5" />
          طلب جديد
        </button>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-orange-400">145</p>
          <p className="text-gray-400 text-sm mt-1">طلبات اليوم</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-blue-400">32</p>
          <p className="text-gray-400 text-sm mt-1">جديدة</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-purple-400">28</p>
          <p className="text-gray-400 text-sm mt-1">قيد التنفيذ</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-green-400">85</p>
          <p className="text-gray-400 text-sm mt-1">مكتملة</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-green-400">52,800</p>
          <p className="text-gray-400 text-sm mt-1">الإيرادات</p>
        </div>
      </div>
      <div className="card p-6">
        <h2 className="text-xl font-semibold text-white mb-4">آخر طلبات الليموزين</h2>
        <p className="text-gray-400 text-center py-8">لا توجد بيانات</p>
      </div>
    </div>
  )
}
