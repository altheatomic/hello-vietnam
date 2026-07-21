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
  'grab': 'assets/images/popular_apps/grab.webp',
  'zalo': 'assets/images/popular_apps/zalo.webp',
  'shopeefood': 'assets/images/popular_apps/shopeefood.webp',
  'green_sm': 'assets/images/popular_apps/green_sm.webp',
  'thecoffeehouse': 'assets/images/popular_apps/thecoffeehouse.webp',
  'tiki': 'assets/images/popular_apps/tiki.webp',
  'momo': 'assets/images/popular_apps/momo.webp',
  'vinbus': 'assets/images/popular_apps/vinbus.webp',
  'foody': 'assets/images/popular_apps/foody.webp',
  'oneu': 'assets/images/popular_apps/oneu.webp',
  'klook': 'assets/images/popular_apps/klook.webp',
};

final popularAppsItems = <PopularAppsItem>[
  // Ratings and download bands verified on Google Play on 2026-07-21.
  PopularAppsItem(
    id: 'grab',
    name: 'Grab',
    category: 'Transportation',
    description: 'Ride-hailing, food delivery & more',
    rating: 4.8,
    downloads: '100M+',
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
    rating: 2.3,
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
    id: 'green_sm',
    name: 'Green SM',
    category: 'Transportation',
    description: 'Electric rides, delivery & more',
    rating: 4.4,
    downloads: '10M+',
    logoUrl: popularAppLogoUrls['green_sm']!,
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
    rating: 3.6,
    downloads: '500K+',
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
    rating: 4.0,
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
    rating: 4.3,
    downloads: '10M+',
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
    rating: 4.3,
    downloads: '100K+',
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
    rating: 3.8,
    downloads: '1M+',
    logoUrl: popularAppLogoUrls['foody']!,
    gradientColors: <Color>[
      Color(0xFFF87171),
      Color(0xFFF43F5E),
      Color(0xFFEF4444),
    ],
    accentColor: Color(0xFFEF4444),
  ),
  PopularAppsItem(
    id: 'oneu',
    name: 'Techcombank OneU',
    category: 'Loyalty & Rewards',
    description: 'U-Point rewards, vouchers & payments',
    rating: 3.9,
    downloads: '5M+',
    logoUrl: popularAppLogoUrls['oneu']!,
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
    rating: 4.4,
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
    downloadUrl:
        'https://play.google.com/store/apps/details?id=com.grabtaxi.passenger',
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
    downloadUrl: 'https://play.google.com/store/apps/details?id=com.zing.zalo',
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
    downloadUrl:
        'https://play.google.com/store/apps/details?id=com.deliverynow',
    imageUrl:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1000&q=80',
  ),
  'green_sm': PopularAppsPost(
    appId: 'green_sm',
    title: 'Green SM Guide',
    ctaLabel: 'Open / Download Green SM',
    summaryTitle: 'What is Green SM?',
    summaryBody:
        'Green SM, formerly Xanh SM in Vietnam, offers electric car and motorbike rides together with delivery and food services.',
    stepsTitle: 'How to use Green SM in Vietnam?',
    steps: <String>[
      'Download Green SM and register your account.',
      'Choose a car, motorbike, delivery, or food service.',
      'Enter pickup and destination details.',
      'Confirm the price and wait for the driver or rider.',
    ],
    logoUrl: popularAppLogoUrls['green_sm']!,
    accentColor: Color(0xFF22C55E),
    downloadUrl:
        'https://play.google.com/store/apps/details?id=com.gsm.customer',
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
    downloadUrl:
        'https://play.google.com/store/apps/details?id=com.thecoffeehouse.guestapp',
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
    downloadUrl:
        'https://play.google.com/store/apps/details?id=vn.tiki.app.tikiandroid',
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
    downloadUrl:
        'https://play.google.com/store/apps/details?id=com.mservice.momotransfer',
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
    downloadUrl:
        'https://play.google.com/store/apps/details?id=vn.vinbus.app.prd',
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
    downloadUrl:
        'https://play.google.com/store/apps/details?id=com.foody.vn.activity',
    imageUrl:
        'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1000&q=80',
  ),
  'oneu': PopularAppsPost(
    appId: 'oneu',
    title: 'Techcombank OneU Guide',
    ctaLabel: 'Open / Download OneU',
    summaryTitle: 'What is Techcombank OneU?',
    summaryBody:
        'Techcombank OneU is the current version of the former VinID app, combining U-Point rewards, vouchers, payments, and partner benefits.',
    stepsTitle: 'How to use OneU rewards?',
    steps: <String>[
      'Create an account with your phone number.',
      'Check your U-Point balance and available vouchers.',
      'Choose a participating partner or benefit.',
      'Redeem U-Points or pay when the option is available.',
    ],
    logoUrl: popularAppLogoUrls['oneu']!,
    accentColor: Color(0xFF8B5CF6),
    downloadUrl:
        'https://play.google.com/store/apps/details?id=com.vingroup.vinid',
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
    downloadUrl: 'https://play.google.com/store/apps/details?id=com.klook',
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1000&q=80',
  ),
};
