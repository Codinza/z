import { Plus } from 'lucide-react'

export default function News() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">إدارة الأخبار والمحتوى</h1>
          <p className="text-gray-400 mt-1">إدارة الأخبار والإعلانات والمحتوى</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors font-medium">
          <Plus className="w-5 h-5" />
          محتوى جديد
        </button>
      </div>
      <div className="card p-6">
        <p className="text-gray-400 text-center py-8">لا توجد محتويات</p>
      </div>
    </div>
  )
}
