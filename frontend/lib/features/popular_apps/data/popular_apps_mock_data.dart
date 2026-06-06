import 'package:flutter/material.dart';
import 'package:hellovietnam/features/popular_apps/domain/popular_apps_item.dart';
import 'package:hellovietnam/features/popular_apps/domain/popular_apps_post.dart';

const popularAppsCategories = <String>[
  'All',
  'Transportation',
  'Food Delivery',
  'Communication',
  'Shopping',
  'Travel & Activities',
];

const Map<String, String> popularAppLogoUrls = <String, String>{
  'grab':
      'https://upload.wikimedia.org/wikipedia/commons/thumb/7/74/Grab_%28application%29_logo.svg/512px-Grab_%28application%29_logo.svg.png',
  'zalo':
      'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Icon_of_Zalo.svg/512px-Icon_of_Zalo.svg.png',
  'shopeefood':
      'https://seeklogo.com/images/S/shopee-food-logo-DF48CF6BAB-seeklogo.com.png',
  'gojek':
      'https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/Gojek_logo_2019.svg/512px-Gojek_logo_2019.svg.png',
  'thecoffeehouse':
      'https://inkythuatso.com/uploads/thumbnails/800/2021/11/logo-the-coffee-house-inkythuatso-01-25-09-21-38.jpg',
  'tiki':
      'https://salt.tikicdn.com/ts/upload/e4/49/6c/270be9859abd5f5ec5071da65fab0a94.png',
  'momo':
      'https://cdn.haitrieu.com/wp-content/uploads/2022/10/Logo-MoMo-Square.png',
  'vinbus': 'https://vinbus.vn/static/media/logo.5c54a8bb.svg',
  'foody':
      'https://cdn.haitrieu.com/wp-content/uploads/2022/01/Logo-Foody.vn.png',
  'vinid':
      'https://upload.wikimedia.org/wikipedia/vi/thumb/4/47/VinID_logo.svg/1200px-VinID_logo.svg.png',
  'klook':
      'https://res.klook.com/image/upload/fl_lossy.progressive/q_85/c_fill,w_400/v1596002708/blog/wg8qzuspkcaxwrgceazn.webp',
};

final popularAppsItems = <PopularAppsItem>[
  PopularAppsItem(
    id: 'grab',
    name: 'Grab',
    category: 'Transportation',
    description: 'Ride-hailing, food delivery & more',
    rating: 4.5,
    downloads: '50M+',
    logoUrl: popularAppLogoUrls['grab']!,
    gradientColors: <Color>[
      Color(0xFF34D399),
      Color(0xFF22C55E),
      Color(0xFF10B981),
    ],
    accentColor: Color(0xFF10B981),
  ),
  PopularAppsItem(
    id: 'zalo',
    name: 'Zalo',
    category: 'Communication',
    description: 'Chat, call & connect with locals',
    rating: 4.3,
    downloads: '100M+',
    logoUrl: popularAppLogoUrls['zalo']!,
    gradientColors: <Color>[
      Color(0xFF60A5FA),
      Color(0xFF06B6D4),
      Color(0xFF3B82F6),
    ],
    accentColor: Color(0xFF0EA5E9),
  ),
  PopularAppsItem(
    id: 'shopeefood',
    name: 'ShopeeFood',
    category: 'Food Delivery',
    description: 'Order Vietnamese food & drinks',
    rating: 4.4,
    downloads: '10M+',
    logoUrl: popularAppLogoUrls['shopeefood']!,
    gradientColors: <Color>[
      Color(0xFFFB923C),
      Color(0xFFEF4444),
      Color(0xFFF97316),
    ],
    accentColor: Color(0xFFF97316),
  ),
  PopularAppsItem(
    id: 'gojek',
    name: 'Gojek',
    category: 'Transportation',
    description: 'Ride, food & lifestyle services',
    rating: 4.2,
    downloads: '20M+',
    logoUrl: popularAppLogoUrls['gojek']!,
    gradientColors: <Color>[
      Color(0xFF4ADE80),
      Color(0xFF10B981),
      Color(0xFF22C55E),
    ],
    accentColor: Color(0xFF22C55E),
  ),
  PopularAppsItem(
    id: 'thecoffeehouse',
    name: 'The Coffee House',
    category: 'Food & Drink',
    description: 'Order coffee & find nearby cafes',
    rating: 4.6,
    downloads: '5M+',
    logoUrl: popularAppLogoUrls['thecoffeehouse']!,
    gradientColors: <Color>[
      Color(0xFFFBBF24),
      Color(0xFFF97316),
      Color(0xFFF59E0B),
    ],
    accentColor: Color(0xFFF59E0B),
  ),
  PopularAppsItem(
    id: 'tiki',
    name: 'Tiki',
    category: 'Shopping',
    description: 'Online shopping & quick delivery',
    rating: 4.3,
    downloads: '10M+',
    logoUrl: popularAppLogoUrls['tiki']!,
    gradientColors: <Color>[
      Color(0xFF60A5FA),
      Color(0xFF6366F1),
      Color(0xFF3B82F6),
    ],
    accentColor: Color(0xFF3B82F6),
  ),
  PopularAppsItem(
    id: 'momo',
    name: 'MoMo',
    category: 'Payment & Wallet',
    description: 'E-wallet for payments & transfers',
    rating: 4.5,
    downloads: '50M+',
    logoUrl: popularAppLogoUrls['momo']!,
    gradientColors: <Color>[
      Color(0xFFF472B6),
      Color(0xFFF43F5E),
      Color(0xFFEC4899),
    ],
    accentColor: Color(0xFFEC4899),
  ),
  PopularAppsItem(
    id: 'vinbus',
    name: 'VinBus',
    category: 'Public Transport',
    description: 'Bus routes & electric bus booking',
    rating: 4.1,
    downloads: '1M+',
    logoUrl: popularAppLogoUrls['vinbus']!,
    gradientColors: <Color>[
      Color(0xFFC084FC),
      Color(0xFF8B5CF6),
      Color(0xFFA855F7),
    ],
    accentColor: Color(0xFFA855F7),
  ),
  PopularAppsItem(
    id: 'foody',
    name: 'Foody',
    category: 'Food Discovery',
    description: 'Find restaurants & read reviews',
    rating: 4.4,
    downloads: '10M+',
    logoUrl: popularAppLogoUrls['foody']!,
    gradientColors: <Color>[
      Color(0xFFF87171),
      Color(0xFFF43F5E),
      Color(0xFFEF4444),
    ],
    accentColor: Color(0xFFEF4444),
  ),
  PopularAppsItem(
    id: 'vinid',
    name: 'VinID',
    category: 'Loyalty & Rewards',
    description: 'Rewards program & member benefits',
    rating: 4.0,
    downloads: '10M+',
    logoUrl: popularAppLogoUrls['vinid']!,
    gradientColors: <Color>[
      Color(0xFFA78BFA),
      Color(0xFFA855F7),
      Color(0xFF8B5CF6),
    ],
    accentColor: Color(0xFF8B5CF6),
  ),
  PopularAppsItem(
    id: 'klook',
    name: 'Klook',
    category: 'Travel & Activities',
    description: 'Book tours, attractions & experiences',
    rating: 4.5,
    downloads: '10M+',
    logoUrl: popularAppLogoUrls['klook']!,
    gradientColors: <Color>[
      Color(0xFFFB923C),
      Color(0xFFF59E0B),
      Color(0xFFF97316),
    ],
    accentColor: Color(0xFFFB923C),
  ),
];

final popularAppsPosts = <String, PopularAppsPost>{
  'grab': PopularAppsPost(
    appId: 'grab',
    title: 'Grab Guide',
    ctaLabel: 'Open / Download Grab',
    summaryTitle: 'What is Grab?',
    summaryBody:
        "Grab is Southeast Asia's leading super app, offering ride-hailing, food delivery, and digital payments. In Vietnam, it is essential for getting around cities affordably and safely.",
    stepsTitle: 'How to use Grab for transportation?',
    steps: <String>[
      'Download and open the Grab app.',
      'Create an account using your phone number or email.',
      'Enter your destination and choose a ride type.',
      'Confirm your pickup location and wait for a driver.',
      'Track your driver in real time and enjoy your ride.',
    ],
    logoUrl: popularAppLogoUrls['grab']!,
    accentColor: Color(0xFF10B981),
    downloadUrl: 'https://www.grab.com/vn/en/download/',
    imageUrl:
        'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=1000&q=80',
  ),
  'zalo': PopularAppsPost(
    appId: 'zalo',
    title: 'Zalo Guide',
    ctaLabel: 'Open / Download Zalo',
    summaryTitle: 'What is Zalo?',
    summaryBody:
        'Zalo is one of the most common messaging apps in Vietnam. Locals use it to chat, call, share location and contact shops, hosts, or landlords.',
    stepsTitle: 'How to use Zalo for communication?',
    steps: <String>[
      'Download and open the Zalo app.',
      'Create an account with your phone number.',
      'Add contacts by syncing your phone book or searching by ID.',
      'Use chat, calls, stickers, and location sharing when needed.',
    ],
    logoUrl: popularAppLogoUrls['zalo']!,
    accentColor: Color(0xFF0EA5E9),
    downloadUrl: 'https://zalo.me/',
    imageUrl:
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1000&q=80',
  ),
  'shopeefood': PopularAppsPost(
    appId: 'shopeefood',
    title: 'ShopeeFood Guide',
    ctaLabel: 'Open / Download ShopeeFood',
    summaryTitle: 'What is ShopeeFood?',
    summaryBody:
        'ShopeeFood helps travelers order Vietnamese meals, drinks, desserts, and late-night snacks from nearby restaurants.',
    stepsTitle: 'How to order food with ShopeeFood?',
    steps: <String>[
      'Open the app and choose your delivery address.',
      'Search for restaurants, dishes, or drink shops.',
      'Add items to your cart and review delivery fees.',
      'Place the order and follow the rider status.',
    ],
    logoUrl: popularAppLogoUrls['shopeefood']!,
    accentColor: Color(0xFFF97316),
    downloadUrl: 'https://shopeefood.vn/',
    imageUrl:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1000&q=80',
  ),
  'gojek': PopularAppsPost(
    appId: 'gojek',
    title: 'Gojek Guide',
    ctaLabel: 'Open / Download Gojek',
    summaryTitle: 'What is Gojek?',
    summaryBody:
        'Gojek is useful for booking motorbike rides, car rides, food delivery, and daily services in major Vietnamese cities.',
    stepsTitle: 'How to use Gojek in Vietnam?',
    steps: <String>[
      'Download Gojek and register your account.',
      'Pick a service such as GoRide, GoCar, or food delivery.',
      'Enter pickup and destination details.',
      'Confirm the price and wait for the driver or rider.',
    ],
    logoUrl: popularAppLogoUrls['gojek']!,
    accentColor: Color(0xFF22C55E),
    downloadUrl: 'https://www.gojek.com/vn/',
    imageUrl:
        'https://images.unsplash.com/photo-1558981806-ec527fa84c39?w=1000&q=80',
  ),
  'thecoffeehouse': PopularAppsPost(
    appId: 'thecoffeehouse',
    title: 'The Coffee House Guide',
    ctaLabel: 'Open / Download The Coffee House',
    summaryTitle: 'What is The Coffee House?',
    summaryBody:
        'The Coffee House app lets you find nearby cafes, browse drinks, order delivery, and collect member rewards.',
    stepsTitle: 'How to use it for coffee stops?',
    steps: <String>[
      'Open the app and choose pickup, delivery, or store search.',
      'Browse coffee, tea, snacks, and seasonal drinks.',
      'Select a branch or delivery address.',
      'Pay and collect rewards when available.',
    ],
    logoUrl: popularAppLogoUrls['thecoffeehouse']!,
    accentColor: Color(0xFFF59E0B),
    downloadUrl: 'https://thecoffeehouse.com/',
    imageUrl:
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1000&q=80',
  ),
  'tiki': PopularAppsPost(
    appId: 'tiki',
    title: 'Tiki Guide',
    ctaLabel: 'Open / Download Tiki',
    summaryTitle: 'What is Tiki?',
    summaryBody:
        'Tiki is a Vietnamese shopping app for travel essentials, electronics, gifts, books, and home delivery.',
    stepsTitle: 'How to shop with Tiki?',
    steps: <String>[
      'Search for the item you need.',
      'Check seller rating, delivery date, and return policy.',
      'Add items to cart and enter your address.',
      'Choose payment method and track the delivery.',
    ],
    logoUrl: popularAppLogoUrls['tiki']!,
    accentColor: Color(0xFF3B82F6),
    downloadUrl: 'https://tiki.vn/',
    imageUrl:
        'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=1000&q=80',
  ),
  'momo': PopularAppsPost(
    appId: 'momo',
    title: 'MoMo Guide',
    ctaLabel: 'Open / Download MoMo',
    summaryTitle: 'What is MoMo?',
    summaryBody:
        'MoMo is a popular Vietnamese e-wallet for QR payments, transfers, bills, tickets, and promotions.',
    stepsTitle: 'How to use MoMo for payments?',
    steps: <String>[
      'Create an account with your phone number.',
      'Link a supported card or bank account if available.',
      'Scan merchant QR codes or use in-app bill services.',
      'Confirm the payment and save the receipt.',
    ],
    logoUrl: popularAppLogoUrls['momo']!,
    accentColor: Color(0xFFEC4899),
    downloadUrl: 'https://momo.vn/',
    imageUrl:
        'https://images.unsplash.com/photo-1563013544-824ae1b704d3?w=1000&q=80',
  ),
  'vinbus': PopularAppsPost(
    appId: 'vinbus',
    title: 'VinBus Guide',
    ctaLabel: 'Open / Download VinBus',
    summaryTitle: 'What is VinBus?',
    summaryBody:
        'VinBus helps users check electric bus routes, stops, schedules, and public transport options in supported cities.',
    stepsTitle: 'How to plan a bus ride?',
    steps: <String>[
      'Open the app and search your destination.',
      'Check nearby stops and route options.',
      'Review departure times before leaving.',
      'Follow the route and stop information during the ride.',
    ],
    logoUrl: popularAppLogoUrls['vinbus']!,
    accentColor: Color(0xFFA855F7),
    downloadUrl: 'https://vinbus.vn/',
    imageUrl:
        'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=1000&q=80',
  ),
  'foody': PopularAppsPost(
    appId: 'foody',
    title: 'Foody Guide',
    ctaLabel: 'Open / Download Foody',
    summaryTitle: 'What is Foody?',
    summaryBody:
        'Foody is a food discovery app where travelers can find restaurants, cafes, menus, photos, and local reviews.',
    stepsTitle: 'How to find places with Foody?',
    steps: <String>[
      'Search for a dish, restaurant, or location.',
      'Compare reviews, photos, and price ranges.',
      'Save places you want to try.',
      'Use the address and reviews before visiting.',
    ],
    logoUrl: popularAppLogoUrls['foody']!,
    accentColor: Color(0xFFEF4444),
    downloadUrl: 'https://www.foody.vn/',
    imageUrl:
        'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1000&q=80',
  ),
  'vinid': PopularAppsPost(
    appId: 'vinid',
    title: 'VinID Guide',
    ctaLabel: 'Open / Download VinID',
    summaryTitle: 'What is VinID?',
    summaryBody:
        'VinID is a loyalty and rewards app connected with VinGroup services, shopping, points, and member benefits.',
    stepsTitle: 'How to use VinID rewards?',
    steps: <String>[
      'Create an account with your phone number.',
      'Scan your member code when shopping with partners.',
      'Check points, vouchers, and promotions.',
      'Redeem benefits when available.',
    ],
    logoUrl: popularAppLogoUrls['vinid']!,
    accentColor: Color(0xFF8B5CF6),
    downloadUrl: 'https://vinid.net/',
    imageUrl:
        'https://images.unsplash.com/photo-1607082349566-187342175e2f?w=1000&q=80',
  ),
  'klook': PopularAppsPost(
    appId: 'klook',
    title: 'Klook Guide',
    ctaLabel: 'Open / Download Klook',
    summaryTitle: 'What is Klook?',
    summaryBody:
        'Klook helps travelers book tours, tickets, airport transfers, attractions, and local experiences before or during a trip.',
    stepsTitle: 'How to book activities with Klook?',
    steps: <String>[
      'Search your destination or activity type.',
      'Compare packages, dates, and reviews.',
      'Book tickets and keep the voucher in the app.',
      'Show the QR code or voucher at the attraction.',
    ],
    logoUrl: popularAppLogoUrls['klook']!,
    accentColor: Color(0xFFFB923C),
    downloadUrl: 'https://www.klook.com/',
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1000&q=80',
  ),
};
