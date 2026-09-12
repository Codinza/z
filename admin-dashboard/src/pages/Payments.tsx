export default function Payments() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">المدفوعات</h1>
        <p className="text-gray-400 mt-1">إدارة المدفوعات والإيرادات</p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-green-400">2.4M</p>
          <p className="text-gray-400 text-sm mt-1">إجمالي الإيرادات</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-orange-400">45,320</p>
          <p className="text-gray-400 text-sm mt-1">إيرادات اليوم</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-blue-400">1.2M</p>
          <p className="text-gray-400 text-sm mt-1">المدفوعات المكتملة</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-3xl font-bold text-yellow-400">250K</p>
          <p className="text-gray-400 text-sm mt-1">المدفوعات المعلقة</p>
        </div>
      </div>
      <div className="card p-6">
        <h2 className="text-xl font-semibold text-white mb-4">آخر المعاملات</h2>
        <p className="text-gray-400 text-center py-8">لا توجد معاملات</p>
      </div>
    </div>
  )
}
