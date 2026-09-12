import { MapPin } from 'lucide-react'

export default function LiveTracking() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">التتبع المباشر</h1>
        <p className="text-gray-400 mt-1">تتبع السائقين والشحنات في الوقت الفعلي</p>
      </div>
      <div className="card p-6">
        <div className="relative w-full h-96 bg-black-800 rounded-lg overflow-hidden border border-gray-700 flex items-center justify-center">
          <div className="text-center">
            <MapPin className="w-12 h-12 text-orange-500/50 mx-auto mb-3" />
            <p className="text-gray-400">خريطة تتبع مباشرة</p>
            <p className="text-sm text-gray-500 mt-1">جاري تحميل الخريطة...</p>
          </div>
        </div>
      </div>
    </div>
  )
}
