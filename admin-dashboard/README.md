# RideFlow Admin Dashboard

Premium admin panel for RideFlow logistics and transportation platform.

## 🎨 Design System

- **Color Palette**: BLACK × ORANGE × WHITE
- **Interface**: RTL Arabic interface
- **Architecture**: Desktop-first responsive layout
- **Brand**: Enterprise logistics platform aesthetic

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

Server runs at `http://localhost:3000`

### Build

```bash
npm run build
```

### Type Check

```bash
npm run type-check
```

## 📁 Project Structure

```
src/
├── components/
│   ├── layout/
│   │   ├── DashboardLayout.tsx
│   │   ├── Sidebar.tsx
│   │   └── Header.tsx
│   └── dashboard/
│       ├── StatCard.tsx
│       ├── AnalyticsChart.tsx
│       ├── ShipmentsOverview.tsx
│       ├── LiveMap.tsx
│       └── RecentShipments.tsx
├── pages/
│   ├── Dashboard.tsx
│   ├── Shipments.tsx
│   ├── Drivers.tsx
│   ├── Customers.tsx
│   ├── Limousine.tsx
│   ├── LiveTracking.tsx
│   ├── Payments.tsx
│   ├── Reports.tsx
│   ├── Notifications.tsx
│   ├── News.tsx
│   ├── Employees.tsx
│   ├── Settings.tsx
│   ├── ShipmentDetail.tsx
│   └── Login.tsx
├── App.tsx
├── main.tsx
└── index.css
```

## 🎯 Features

### Dashboard
- Real-time KPI cards
- Analytics charts (shipments & revenue)
- Status distribution (pie chart)
- Live tracking map
- Recent shipments table

### Management
- Shipments management with advanced filters
- Driver management with performance metrics
- Customer management
- Limousine service management
- Payment tracking and financial reports

### Navigation
- Fixed sidebar with premium design
- Responsive header with search and notifications
- Active navigation indicator with orange accent
- User profile and logout

### Design Quality
- Premium card-based layout
- Consistent spacing (8px system)
- Smooth transitions and interactions
- Status badges with semantic colors
- Professional data tables
- Loading states and empty states

## 🛠 Technology Stack

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **React Router** - Navigation
- **Recharts** - Data visualization
- **Axios** - HTTP client
- **Socket.io-client** - Real-time updates
- **Zustand** - State management
- **Lucide Icons** - Icon library

## 🔌 API Integration

The dashboard connects to the backend API at `http://localhost:4000`

### Endpoints (to be configured)

- `GET /api/dashboard/stats` - Dashboard statistics
- `GET /api/shipments` - List shipments
- `GET /api/drivers` - List drivers
- `GET /api/customers` - List customers
- `GET /api/payments` - Payment data
- etc.

## 📱 Responsive Design

- **Desktop**: Full sidebar + full content
- **Tablet**: Collapsible sidebar
- **Mobile**: Drawer navigation

## ✅ Accessibility

- Excellent color contrast
- Clear typography (RTL Arabic)
- Large click targets
- Keyboard-friendly interactions
- Semantic HTML

## 📝 License

Proprietary - RideFlow

## 👥 Support

For questions or issues, contact the development team.
