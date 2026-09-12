import { BarChart3, Download } from 'lucide-react'

export default function Reports() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">التقارير</h1>
          <p className="text-gray-400 mt-1">عرض التقارير المتقدمة للمنصة</p>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {['تقارير الشحنات', 'تقارير الليموزين', 'تقارير الإيرادات', 'تقارير السائقين', 'تقارير العملاء', 'تقارير الأداء'].map((report) => (
          <div key={report} className="card p-4 hover:shadow-lg transition-shadow cursor-pointer">
            <div className="flex items-center gap-3 mb-3">
              <div className="p-3 bg-orange-500/10 text-orange-400 rounded-lg">
                <BarChart3 className="w-6 h-6" />
              </div>
              <span className="text-white font-medium">{report}</span>
            </div>
            <button className="flex items-center gap-2 text-orange-400 hover:text-orange-300 text-sm">
              <Download className="w-4 h-4" />
              تصدير
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}
