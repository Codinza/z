# Database Migration Guide

## Changes Made to Prisma Schema

### New Models Added
1. **Company** - Represents limousine or shipping companies
   - userId (reference to User)
   - companyType (LIMOUSINE or SHIPPING)
   - companyName, companyPhone, address
   - status (pending, approved, rejected, active)

2. **CompanyEmployee** - Staff members of companies
   - companyId, name, phone, email, password, role

3. **Order** - Replaces Trip model for limousine and shipping services
   - customerId, companyId
   - serviceType (LIMOUSINE or SHIPPING)
   - status (NEW, COMPANY_REVIEWING, COMPANY_ACCEPTED, COMPANY_REJECTED, PRICE_SENT, CUSTOMER_APPROVED, CUSTOMER_REJECTED, CONFIRMED, COMPLETED, CANCELLED)
   - Limousine-specific fields: pickupAddress, dropoffAddress, passengerCount, dateTime, notes
   - Shipping-specific fields: pickupAddress, dropoffAddress, details, type, dateTime, notes
   - Pricing fields: customerOfferPrice, companyOfferPrice, finalPrice
   - customerContactVisible (boolean for data masking)
   - rejectionReason (nullable)

4. **PriceOffer** - Track price negotiations between customer and company
   - orderId, customerId, companyId
   - offeredPrice, sentBy, status, rejectionReason

### Models Modified

1. **User** - Updated role field
   - Old values: customer, driver, admin
   - New values: customer, driver, admin, company, super_admin
   - Added relations: company, orders, priceOffers

2. **Trip** - Kept for backward compatibility
   - No changes to Trip model itself

3. **Payment** - Updated relations
   - Changed from tripId to orderId
   - Updated trip relation to order relation

4. **Rating** - Updated relations
   - Changed from tripId to orderId
   - Added optional driverId field

5. **Notification** - Enhanced
   - Added companyId field (nullable)
   - Added orderId field (optional)
   - Made userId optional to support company notifications

## Migration Steps

1. Back up your current database
2. Run Prisma migration to update schema:
   ```bash
   npm run prisma:migrate
   ```
3. Regenerate Prisma Client:
   ```bash
   npm run prisma:generate
   ```
4. If needed, seed initial super admin user via API

## Environment Variables

No new environment variables required for basic functionality.
Database connection string remains the same.

## Backward Compatibility

- Old Trip model is kept for driver-based ride sharing
- New Order model is for company-based limousine and shipping services
- Both systems can coexist

## API Changes

### New Endpoints

#### Company Management
- POST /api/company/register - Register new company
- POST /api/company/login - Company login
- GET /api/company/dashboard - Get company dashboard
- GET /api/company/orders - Get orders for company
- POST /api/company/orders/:orderId/review - Mark order as reviewing
- POST /api/company/orders/:orderId/accept - Accept order with customer's price
- POST /api/company/orders/:orderId/reject - Reject order
- POST /api/company/orders/:orderId/counter-offer - Send counter price offer

#### Order Management (Customer)
- POST /api/orders/limousine - Create limousine order
- POST /api/orders/shipping - Create shipping order
- GET /api/orders - Get customer's orders
- GET /api/orders/:orderId - Get order details
- POST /api/orders/:orderId/approve-price - Approve company's price
- POST /api/orders/:orderId/reject-price - Reject company's price
- POST /api/orders/:orderId/confirm - Confirm order
- POST /api/orders/:orderId/cancel - Cancel order

#### Admin Management
- GET /api/admin/companies/pending - Get pending company approvals
- POST /api/admin/companies/:id/approve - Approve company
- POST /api/admin/companies/:id/reject - Reject company
- GET /api/admin/orders - Get all orders
- GET /api/admin/customers - Get all customers
- GET /api/admin/companies - Get all companies
- GET /api/admin/stats - Get comprehensive admin stats

## Data Security

Customer phone numbers are masked for:
- New orders (status: NEW)
- Orders being reviewed (status: COMPANY_REVIEWING)
- Orders with company counter-offer (status: PRICE_SENT)

Phone numbers are shown in full only after:
- Customer approves price (status: CUSTOMER_APPROVED, CONFIRMED, etc.)
- Super admin viewing

This is enforced at both the API level and database level through application logic.
