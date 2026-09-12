import { Save } from 'lucide-react'

export default function Settings() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">الإعدادات</h1>
        <p className="text-gray-400 mt-1">إدارة إعدادات النظام والتكوينات</p>
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {['بيانات الشركة', 'الحساب', 'الإشعارات', 'الأمان', 'الدفع', 'الخريطة'].map((section) => (
          <div key={section} className="card p-6">
            <h2 className="text-xl font-semibold text-white mb-4">{section}</h2>
            <div className="space-y-3">
              <div>
                <label className="text-sm text-gray-300">الإعدادات</label>
                <input type="text" className="input-field w-full mt-1" placeholder="قيمة" />
              </div>
            </div>
          </div>
        ))}
      </div>
      <div className="flex justify-end">
        <button className="flex items-center gap-2 px-6 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors font-medium">
          <Save className="w-5 h-5" />
          حفظ التغييرات
        </button>
      </div>
    </div>
  )
}
