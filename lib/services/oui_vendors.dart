/// Petite table des fabricants les plus courants (3 premiers octets de la MAC).
/// À compléter plus tard avec la base complète de l'IEEE.
const Map<String, String> ouiVendors = {
  // Apple
  '00:1C:B3': 'Apple', 'F0:18:98': 'Apple', 'AC:BC:32': 'Apple',
  '3C:22:FB': 'Apple', 'A4:83:E7': 'Apple', 'BC:D0:74': 'Apple',
  '28:CF:E9': 'Apple', 'D0:81:7A': 'Apple', '8C:85:90': 'Apple',
  // Samsung
  '00:16:32': 'Samsung', '5C:0A:5B': 'Samsung', 'E8:50:8B': 'Samsung',
  '8C:77:12': 'Samsung', 'FC:A1:3E': 'Samsung', '34:14:5F': 'Samsung',
  // Huawei
  '00:E0:FC': 'Huawei', '48:46:FB': 'Huawei', '70:72:3C': 'Huawei',
  'E0:24:7F': 'Huawei', '88:53:D4': 'Huawei', 'AC:E2:15': 'Huawei',
  // Xiaomi
  '64:09:80': 'Xiaomi', '28:6C:07': 'Xiaomi', '50:8F:4C': 'Xiaomi',
  '7C:1D:D9': 'Xiaomi', 'F8:A2:D6': 'Xiaomi',
  // Tecno / Infinix / itel (Transsion)
  '0C:98:38': 'Transsion (Tecno/Infinix)', 'A8:9C:ED': 'Transsion (Tecno/Infinix)',
  // Oppo / Realme / OnePlus
  '2C:5B:B8': 'Oppo', 'A4:3D:78': 'Oppo', '94:65:2D': 'OnePlus',
  // TP-Link
  '50:C7:BF': 'TP-Link', 'F4:F2:6D': 'TP-Link', '60:32:B1': 'TP-Link',
  'B0:4E:26': 'TP-Link', '98:DA:C4': 'TP-Link', 'C0:06:C3': 'TP-Link',
  // ZTE
  '00:19:C6': 'ZTE', '34:4B:50': 'ZTE', 'C8:64:C7': 'ZTE', 'F4:B8:A7': 'ZTE',
  // Tenda
  'C8:3A:35': 'Tenda', 'CC:2D:21': 'Tenda',
  // Intel (PC portables)
  '00:1B:21': 'Intel', '3C:A9:F4': 'Intel', 'A4:34:D9': 'Intel',
  '8C:8D:28': 'Intel', 'F8:94:C2': 'Intel',
  // Realtek / Dell / HP / Lenovo
  '00:E0:4C': 'Realtek', '00:14:22': 'Dell', 'F8:BC:12': 'Dell',
  '3C:D9:2B': 'HP', '00:21:5A': 'HP', '54:EE:75': 'Lenovo',
  // Google / Amazon / LG / Sony
  'F4:F5:D8': 'Google', '3C:5A:B4': 'Google', 'FC:65:DE': 'Amazon',
  'A8:23:FE': 'LG', '00:1D:BA': 'Sony',
  // Raspberry Pi / Espressif (objets connectés)
  'B8:27:EB': 'Raspberry Pi', 'DC:A6:32': 'Raspberry Pi',
  '24:0A:C4': 'Espressif (objet connecté)', '30:AE:A4': 'Espressif (objet connecté)',
};

String? lookupVendor(String? mac) {
  if (mac == null || mac.length < 8) return null;
  return ouiVendors[mac.substring(0, 8).toUpperCase()];
}
