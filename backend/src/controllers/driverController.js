import { driverService } from '../services/driverService.js';

class DriverController {
  async listDrivers(_, res) {
    return res.json({ drivers: await driverService.listDrivers() });
  }

  async getDriverById(req, res) {
    const driver = await driverService.getDriverById(req.params.id);
    if (!driver) {
      return res.status(404).json({ message: 'Driver not found' });
    }
    return res.json({ driver });
  }
  async getWallet(req, res) {
    try {
      const id =
        req.params.id && req.params.id !== 'me' ? req.params.id : req.user?.id;
      const wallet = await driverService.getDriverWallet(id, req.user?.id);
      return res.json(wallet);
    } catch (e) {
      return res.status(400).json({ message: e.message });
    }
  }

  async recharge(_req, res) {
    return res.status(501).json({
      message: 'الشحن المباشر غير متاح. أرسل طلب شحن مع إيصال للمراجعة.',
    });
  }

  async createTopUpRequest(req, res) {
    try {
      let id = req.params.id;
      if (!id || id === 'me') {
        id = req.user?.id;
      }
      const result = await driverService.createTopUpRequest(
        id,
        req.body.amount,
        req.body.paymentMethod,
        req.body.receiptImage,
        req.user?.id,
      );
      return res.status(201).json(result);
    } catch (e) {
      return res.status(400).json({ message: e.message, error: e.message });
    }
  }

  async createWalletCheckout(req, res) {
    try {
      const result = await driverService.createWalletCheckout(req.params.id, req.body.amount);
      return res.status(201).json(result);
    } catch (e) {
      return res.status(400).json({ message: e.message });
    }
  }

  async getHistory(req, res) {
    try {
      const history = await driverService.getDriverHistory(req.params.id);
      return res.json({ history });
    } catch (e) {
      return res.status(400).json({ message: e.message });
    }
  }

  async getRatings(req, res) {
    try {
      const ratingsData = await driverService.getDriverRatings(req.params.id);
      return res.json(ratingsData);
    } catch (e) {
      return res.status(400).json({ message: e.message });
    }
  }
}

export const driverController = new DriverController();
