import { MapPin, Filter } from 'lucide-react'

export default function LiveMap() {
  return (
    <div className="card p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold text-white">التتبع المباشر</h2>
          <p className="text-sm text-gray-400 mt-1">خريطة حية لجميع السائقين والشحنات</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-black-800 text-gray-300 hover:bg-black-700 rounded-lg transition-colors text-sm">
          <Filter className="w-4 h-4" />
          تصفية
        </button>
      </div>

      {/* Map Placeholder - In production, integrate with actual map library like Leaflet */}
      <div className="relative w-full h-96 bg-black-800 rounded-lg overflow-hidden border border-gray-700 flex items-center justify-center">
        <div className="text-center">
          <MapPin className="w-12 h-12 text-orange-500/50 mx-auto mb-3" />
          <p className="text-gray-400">خريطة حية للتتبع</p>
          <p className="text-sm text-gray-500 mt-1">جاري تحميل الخريطة...</p>
        </div>

        {/* Sample Markers */}
        <div className="absolute top-1/4 right-1/3 w-8 h-8 bg-orange-500 rounded-full border-2 border-orange-300 flex items-center justify-center cursor-pointer hover:scale-110 transition-transform" title="Driver 1">
          <div className="w-4 h-4 bg-white rounded-full"></div>
        </div>

        <div className="absolute top-2/3 right-1/4 w-8 h-8 bg-orange-500 rounded-full border-2 border-orange-300 flex items-center justify-center cursor-pointer hover:scale-110 transition-transform" title="Driver 2">
          <div className="w-4 h-4 bg-white rounded-full"></div>
        </div>

        <div className="absolute top-1/2 right-1/2 w-6 h-6 bg-blue-400 rounded border-2 border-blue-300 flex items-center justify-center" title="Pickup">
          <div className="w-2 h-2 bg-white rounded-full"></div>
        </div>
      </div>

      {/* Filters */}
      <div className="mt-6 flex flex-wrap gap-2">
        {['كل السائقين', 'الشحنات الحالية', 'المتاحة', 'قيد التوصيل'].map((filter) => (
          <button
            key={filter}
            className="px-4 py-2 bg-black-800 text-gray-300 hover:bg-orange-500/20 hover:text-orange-400 rounded-lg transition-colors text-sm font-medium"
          >
            {filter}
          </button>
        ))}
      </div>
    </div>
  )
}
