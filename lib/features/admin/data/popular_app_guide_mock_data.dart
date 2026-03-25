import '../domain/popular_app_guide.dart';

/// Mock guide posts. Replace with a Supabase/API call when backend is wired.
/// [categoryId] strings match the IDs in [defaultAppCategories].
final List<PopularAppGuide> mockPopularAppGuides = [
  PopularAppGuide(
    id: 'guide-001',
    name: 'Grab',
    categoryId: 'transport',
    packageName: 'com.grabtaxi.passenger',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.grabtaxi.passenger',
    urlImage: 'https://picsum.photos/seed/grab/80/80',
    urlVideo: null,
    description:
        'Book motorbike taxis, cars, and tuk-tuks; order food and send parcels — all in one app.',
    guide:
        '1. Download Grab from the Play Store or App Store.\n'
        '2. Register with your Vietnamese phone number.\n'
        '3. Tap "Transport" to book a GrabBike or GrabCar.\n'
        '4. Enter your destination and confirm the fare.\n'
        '5. Track your driver in real time on the map.',
    createdAt: DateTime(2024, 2, 10),
  ),
  PopularAppGuide(
    id: 'guide-002',
    name: 'Be',
    categoryId: 'transport',
    packageName: 'com.be.driver',
    storeUrl: 'https://play.google.com/store/apps/details?id=com.be.driver',
    urlImage: 'https://picsum.photos/seed/be-app/80/80',
    urlVideo: null,
    description:
        'Vietnam-born ride-hailing app with competitive fares and no surge pricing.',
    guide:
        '1. Install Be from the store.\n'
        '2. Sign up with your phone number — no email needed.\n'
        '3. Choose beBike (motorbike) or beCar.\n'
        '4. Pin your pickup and drop-off on the map.\n'
        '5. Pay by cash or BeWallet.',
    createdAt: DateTime(2024, 2, 14),
  ),
  PopularAppGuide(
    id: 'guide-003',
    name: 'Zalo',
    categoryId: 'chat',
    packageName: 'com.zing.zalo',
    storeUrl: 'https://play.google.com/store/apps/details?id=com.zing.zalo',
    urlImage: 'https://picsum.photos/seed/zalo/80/80',
    urlVideo: 'https://www.example.com/zalo-guide.mp4',
    description:
        "Vietnam's most popular messaging app — chat, voice/video calls, and news feed.",
    guide:
        '1. Download Zalo and enter your phone number.\n'
        '2. Verify with the OTP sent via SMS.\n'
        '3. Allow contacts permission so Zalo can sync friends.\n'
        '4. Tap the chat icon to start a conversation.\n'
        '5. Use "Official Accounts" to follow brands and news.',
    createdAt: DateTime(2024, 3, 1),
  ),
  PopularAppGuide(
    id: 'guide-004',
    name: 'Viber',
    categoryId: 'chat',
    packageName: 'com.viber.voip',
    storeUrl: 'https://play.google.com/store/apps/details?id=com.viber.voip',
    urlImage: 'https://picsum.photos/seed/viber/80/80',
    urlVideo: null,
    description:
        'Free international calls and messaging — widely used among expats and tourists in Vietnam.',
    guide:
        '1. Install Viber and verify your phone number.\n'
        '2. Contacts with Viber are detected automatically.\n'
        '3. Make free HD calls over Wi-Fi.\n'
        '4. Use Viber Out to call landlines at low rates.',
    createdAt: DateTime(2024, 3, 5),
  ),
  PopularAppGuide(
    id: 'guide-005',
    name: 'MoMo',
    categoryId: 'payment',
    packageName: 'vn.momo.standalone',
    storeUrl:
        'https://play.google.com/store/apps/details?id=vn.momo.standalone',
    urlImage: 'https://picsum.photos/seed/momo/80/80',
    urlVideo: 'https://www.example.com/momo-guide.mp4',
    description:
        "Vietnam's leading e-wallet — pay bills, top up phones, and transfer money instantly.",
    guide:
        '1. Download MoMo and register with your phone number.\n'
        '2. Link your bank account or top up via ATM.\n'
        '3. Scan QR codes at stores to pay.\n'
        '4. Use "Send Money" to transfer to any MoMo user for free.\n'
        '5. Pay electricity, water, and internet bills in the "Utilities" tab.',
    createdAt: DateTime(2024, 3, 10),
  ),
  PopularAppGuide(
    id: 'guide-006',
    name: 'ViettelPay',
    categoryId: 'payment',
    packageName: 'com.viettelmoney.android',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.viettelmoney.android',
    urlImage: 'https://picsum.photos/seed/viettel/80/80',
    urlVideo: null,
    description:
        "Viettel's digital wallet — transfers, bill payments, and top-ups with high transaction limits.",
    guide:
        '1. Install ViettelPay and register with a Viettel number.\n'
        '2. Complete eKYC verification to unlock full features.\n'
        '3. Top up via bank transfer or Viettel store.\n'
        "4. Pay by QR code or enter the recipient's phone number.",
    createdAt: DateTime(2024, 3, 18),
  ),
  PopularAppGuide(
    id: 'guide-007',
    name: 'ShopeeFood',
    categoryId: 'delivery',
    packageName: 'com.shopee.food.vn',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.shopee.food.vn',
    urlImage: 'https://picsum.photos/seed/shopeefood/80/80',
    urlVideo: null,
    description:
        'Fast food delivery from hundreds of local restaurants, with frequent discount vouchers.',
    guide:
        '1. Open ShopeeFood (or the Food tab inside Shopee).\n'
        '2. Allow location so restaurants near you appear.\n'
        '3. Browse by cuisine or search for a specific dish.\n'
        '4. Add items to cart and apply any available voucher codes.\n'
        '5. Track the delivery rider on the live map.',
    createdAt: DateTime(2024, 4, 2),
  ),
  PopularAppGuide(
    id: 'guide-008',
    name: 'GrabFood',
    categoryId: 'delivery',
    packageName: 'com.grabtaxi.passenger',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.grabtaxi.passenger',
    urlImage: 'https://picsum.photos/seed/grabfood/80/80',
    urlVideo: null,
    description:
        'Order from thousands of Vietnamese and international restaurants via the Grab super-app.',
    guide:
        '1. Open the Grab app and tap the "Food" icon.\n'
        '2. Browse featured restaurants or search by name.\n'
        '3. Customise your order (size, toppings) before adding to cart.\n'
        '4. Choose GrabPay, cash, or linked card at checkout.\n'
        '5. Real-time tracking shows when your food leaves the restaurant.',
    createdAt: DateTime(2024, 4, 8),
  ),
];
