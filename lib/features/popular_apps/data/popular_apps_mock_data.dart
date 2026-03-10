import 'package:flutter/material.dart';
import 'package:hellovietnam/features/popular_apps/domain/popular_apps_item.dart';
import 'package:hellovietnam/features/popular_apps/domain/popular_apps_post.dart';

const popularAppsCategories = <String>[
  'ALL',
  'TRANSPORT',
  'CHAT',
  'PAYMENT',
  'MORE',
];

const popularAppsItems = <PopularAppsItem>[
  PopularAppsItem(
    id: 'grab',
    name: 'Grab',
    description:
        'Grab is an app for people to book transportation like bike, car or to deliver stuffs. You can also order food and pay cashless in many places.',
    category: 'TRANSPORT',
    logo: 'G',
    badgeColor: Color(0xFFDDF7E4),
    badgeTextColor: Color(0xFF1FA750),
  ),
  PopularAppsItem(
    id: 'zalo',
    name: 'Zalo',
    description:
        'Zalo is one of the most common messaging apps in Vietnam. Locals use it to chat, call, share location and contact shops or landlords.',
    category: 'CHAT',
    logo: 'Z',
    badgeColor: Color(0xFFD9EEFF),
    badgeTextColor: Color(0xFF2797F5),
  ),
  PopularAppsItem(
    id: 'momo',
    name: 'MoMo',
    description:
        'MoMo is a popular Vietnamese e-wallet used for QR payments, transfers and bills. Some features may require local banking setup.',
    category: 'PAYMENT',
    logo: 'M',
    badgeColor: Color(0xFFFCE0F0),
    badgeTextColor: Color(0xFFE85CB2),
  ),
  PopularAppsItem(
    id: 'be',
    name: 'Be',
    description:
        'Be is a local Vietnamese ride-hailing app for booking rides and some delivery services. It can be a useful backup to Grab.',
    category: 'TRANSPORT',
    logo: 'be',
    badgeColor: Color(0xFFDDF7E4),
    badgeTextColor: Color(0xFF1FA750),
  ),
];
const popularAppsPosts = <String, PopularAppsPost>{
  'grab': PopularAppsPost(
    appId: 'grab',
    title: 'Grab Guide',
    ctaLabel: 'Open / Download Grab',
    heroTitle: 'Video Tutorial',
    heroSubtitle: '4:32 minutes',
    summaryTitle: 'What is Grab?',
    summaryBody:
        'Grab is an app for people to book transportation like bike, car or to deliver stuffs. You can also order food and pay cashless in many places.',
    stepsTitle: 'How to use Grab for transportation?',
    steps: [
      'Step 1: Download and open the Grab app.',
      'Step 2: Select your destination and choose a ride option (bike, car, etc.).',
      'Step 3: Confirm your pickup location and book the ride.',
      'Step 4: Track your driver and enjoy your trip!',
    ],
    imageUrl: 'https://example.com/grab-guide.jpg',
  ),
  'zalo': PopularAppsPost(
    appId: 'zalo',
    title: 'Zalo Guide',
    ctaLabel: 'Open / Download Zalo',
    heroTitle: 'Video Tutorial',
    heroSubtitle: '3:45 minutes',
    summaryTitle: 'What is Zalo?',
    summaryBody:
        'Zalo is one of the most common messaging apps in Vietnam. Locals use it to chat, call, share location and contact shops or landlords.',
    stepsTitle: 'How to use Zalo for communication?',
    steps: [
      'Step 1: Download and open the Zalo app.',
      'Step 2: Create an account using your phone number.',
      'Step 3: Add contacts by syncing your phone book or searching by ID.',
      'Step 4: Start chatting, calling, or sharing your location with friends!',
    ],
    imageUrl: 'https://example.com/zalo-guide.jpg',
  ),
  'momo': PopularAppsPost(
    appId: 'momo',
    title: 'MoMo Guide',
    ctaLabel: 'Open / Download MoMo',
    heroTitle: 'Video Tutorial',
    heroSubtitle: '5:10 minutes',
    summaryTitle: 'What is MoMo?',
    summaryBody:
        'MoMo is a popular Vietnamese e-wallet used for QR payments, transfers and bills. Some features may require local banking setup.',
    stepsTitle: 'How to use MoMo for payments?',
    steps: [
      'Step 1: Download and open the MoMo app.',
      'Step 2: Create an account and link your bank card.',
      'Step 3: Use the QR code scanner to pay at supported merchants.',
      'Step 4: You can also transfer money or pay bills easily!',
    ],
    imageUrl: 'https://example.com/momo-guide.jpg',
  ),
  'be': PopularAppsPost(
    appId: 'be',
    title: 'Be Guide',
    ctaLabel: 'Open / Download Be',
    heroTitle: 'Video Tutorial',
    heroSubtitle: '4:00 minutes',
    summaryTitle: 'What is Be?',
    summaryBody:
        'Be is a local Vietnamese ride-hailing app for booking rides and some delivery services. It can be a useful backup to Grab.',
    stepsTitle: 'How to use Be for transportation?',
    steps: [
      'Step 1: Download and open the Be app.',
      'Step 2: Select your destination and choose a ride option (bike, car, etc.).',
      'Step 3: Confirm your pickup location and book the ride.',
      'Step 4: Track your driver and enjoy your trip!',
    ],
    imageUrl: 'https://example.com/be-guide.jpg',
  ),
};
