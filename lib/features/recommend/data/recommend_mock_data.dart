import '../domain/recommend_destination.dart';

// Images use picsum.photos seeds for stable dev placeholders.
// Swap these URLs for real Supabase assets when available.
const List<RecommendDestination> mockRecommendDestinations = [
  RecommendDestination(
    id: 'hanoi',
    name: 'Ha Noi',
    shortDescription: 'Vibrant capital blending ancient heritage with modern city life.',
    description:
        'Hanoi is the capital of Vietnam, known for its historic Old Quarter, peaceful lakes, and rich cultural heritage. The city blends traditional architecture with a lively modern atmosphere, offering a unique and memorable travel experience.',
    imagePath: 'https://picsum.photos/seed/hanoi/800/600',
    rating: 4.7,
    tags: ['History', 'Culture', 'Food'],
    bestTimeTitle: 'Autumn (August – November)',
    bestTimeDetails: [
      'Cool, pleasant weather (20–30°C)',
      'Clear skies, light breeze, ideal for sightseeing',
      'Best period: late October – early November (autumn foliage & cool air)',
    ],
    activities: [
      'Explore Hoan Kiem Lake and Ngoc Son Temple',
      'Walk the 36 Streets of the Old Quarter',
      'Visit the Temple of Literature',
      'Evening street food tour in the Old Quarter',
    ],
    cuisine: [
      RecommendFood(
        name: 'Pho',
        imagePath: 'https://picsum.photos/seed/pho/600/400',
      ),
      RecommendFood(
        name: 'Grilled Pork with Vermicelli',
        imagePath: 'https://picsum.photos/seed/bun/600/400',
      ),
      RecommendFood(
        name: 'Turmeric Grilled Fish',
        imagePath: 'https://picsum.photos/seed/fish/600/400',
      ),
    ],
    tips: [
      'Avoid peak traffic hours (7–9 AM, 5–7 PM).',
      'Carry small cash for street food and local shops.',
      'Dress politely when visiting temples and pagodas.',
      'Watch your belongings in crowded areas like the Old Quarter.',
      'Check weather (autumn cool, spring drizzly) before planning outdoor activities.',
      'Use reputable taxi or ride apps (Grab, Gojek, Be).',
    ],
    gallery: [
      'https://picsum.photos/seed/hanoi1/300/200',
      'https://picsum.photos/seed/hanoi2/300/200',
      'https://picsum.photos/seed/hanoi3/300/200',
    ],
    highlights:
        'Hanoi blends ancient charm with modern energy. Must-sees include Hoan Kiem Lake, the Ho Chi Minh Mausoleum, and the vibrant 36 Streets of the Old Quarter.',
    bestMonths: [10, 11, 3, 4],
  ),

  RecommendDestination(
    id: 'dalat',
    name: 'Da Lat',
    shortDescription: 'Misty highland city of pine forests, flower gardens and cool air.',
    description:
        'Da Lat is a misty highland city known for its cool climate, pine forests, flower gardens, and peaceful lakes. It is one of the most popular destinations in Vietnam for relaxation and sightseeing.',
    imagePath: 'https://picsum.photos/seed/dalat/800/600',
    rating: 4.7,
    tags: ['Nature', 'Romance', 'Adventure'],
    bestTimeTitle: 'November to March (Dry Season)',
    bestTimeDetails: [
      'Cool, crisp weather (15–25°C)',
      'Flowers in full bloom across the city',
      'Best for outdoor activities and trekking',
    ],
    activities: [
      'Visit Xuan Huong Lake',
      'Explore Cau Dat Tea Hill',
      'Hike Langbiang Mountain',
      'Experience the Da Lat Night Market',
    ],
    cuisine: [
      RecommendFood(
        name: 'Banh Trang Nuong (Grilled Rice Paper)',
        imagePath: 'https://picsum.photos/seed/btrang/600/400',
      ),
      RecommendFood(
        name: 'Strawberry Jam & Fresh Strawberries',
        imagePath: 'https://picsum.photos/seed/strawberry/600/400',
      ),
    ],
    tips: [
      'Bring a jacket — evenings are cold year-round.',
      'Rent a motorbike to explore surrounding hills.',
      'Visit the Valley of Love for scenic views.',
    ],
    gallery: [
      'https://picsum.photos/seed/dalat1/300/200',
      'https://picsum.photos/seed/dalat2/300/200',
      'https://picsum.photos/seed/dalat3/300/200',
    ],
    highlights:
        'Da Lat offers serene lakes, green tea hills, cool pine forests, and refreshing mountain views. Visitors can enjoy Xuan Huong Lake, explore Cau Dat Tea Hill, hike Langbiang Mountain, or experience the lively atmosphere of the Da Lat Night Market.',
    bestMonths: [11, 12, 1, 2, 3],
  ),

  RecommendDestination(
    id: 'hochiminh',
    name: 'Ho Chi Minh City',
    shortDescription: "Vietnam's dynamic metropolis of culture, food and nightlife.",
    description:
        "Ho Chi Minh City (Saigon) is Vietnam's largest city, offering a rich mix of history, culture, street food, and modern urban life. The city never sleeps and rewards every type of traveller.",
    imagePath: 'https://picsum.photos/seed/hcmc/800/600',
    rating: 4.96,
    tags: ['Culture', 'Food', 'Nightlife'],
    bestTimeTitle: 'December to April (Dry Season)',
    bestTimeDetails: [
      'Hot and dry weather (25–35°C)',
      'Ideal for outdoor sightseeing',
      'Festive atmosphere during Tet (Jan–Feb)',
    ],
    activities: [
      'Visit War Remnants Museum',
      'Explore Ben Thanh Market',
      'Tour Cu Chi Tunnels',
      'Rooftop bar hopping in District 1',
    ],
    cuisine: [
      RecommendFood(
        name: 'Banh Mi',
        imagePath: 'https://picsum.photos/seed/banhmi2/600/400',
      ),
      RecommendFood(
        name: 'Com Tam (Broken Rice)',
        imagePath: 'https://picsum.photos/seed/comtam/600/400',
      ),
      RecommendFood(
        name: 'Hu Tieu Noodle Soup',
        imagePath: 'https://picsum.photos/seed/hutieu/600/400',
      ),
    ],
    tips: [
      'Use Grab for safe and affordable transport.',
      'Watch out for motorbikes when crossing streets.',
      'Book popular restaurants in advance on weekends.',
    ],
    gallery: [
      'https://picsum.photos/seed/hcmc1/300/200',
      'https://picsum.photos/seed/hcmc2/300/200',
      'https://picsum.photos/seed/hcmc3/300/200',
    ],
    highlights:
        'HCMC pulses with energy day and night. The historic Notre-Dame Cathedral, Reunification Palace, and the sprawling Ben Thanh Market are must-visit landmarks.',
    bestMonths: [12, 1, 2, 3, 4],
  ),

  RecommendDestination(
    id: 'sapa',
    name: 'Sa Pa',
    shortDescription: 'Dramatic terraced rice fields and ethnic hill-tribe villages.',
    description:
        'Sa Pa is a misty mountain town in northern Vietnam, famous for its spectacular rice terraces, diverse ethnic minority cultures, and outstanding trekking routes.',
    imagePath: 'https://picsum.photos/seed/sapa/800/600',
    rating: 4.5,
    tags: ['Nature', 'Trekking', 'Culture'],
    bestTimeTitle: 'March–May & September–November',
    bestTimeDetails: [
      'Clear skies and comfortable temperatures',
      'Rice terraces at their most photogenic',
      'Ideal for trekking to village homestays',
    ],
    activities: [
      "Trek to Fansipan — Roof of Indochina",
      "Village homestay with H'mong families",
      'Visit Bac Ha Sunday Market',
      'Muong Hoa Valley rice terrace walk',
    ],
    cuisine: [
      RecommendFood(
        name: 'Thang Co (Horse Stew)',
        imagePath: 'https://picsum.photos/seed/thangco/600/400',
      ),
      RecommendFood(
        name: 'Salmon Hot Pot',
        imagePath: 'https://picsum.photos/seed/salmon/600/400',
      ),
    ],
    tips: [
      'Layer clothing — temperatures vary greatly day to night.',
      'Book trekking guides in advance for peak season.',
      'Bring rain gear — fog and drizzle are common.',
    ],
    gallery: [
      'https://picsum.photos/seed/sapa1/300/200',
      'https://picsum.photos/seed/sapa2/300/200',
      'https://picsum.photos/seed/sapa3/300/200',
    ],
    highlights:
        "Sa Pa's emerald-green rice terraces cascading into the valley are one of Vietnam's most breathtaking sights, best experienced on foot with a local guide.",
    bestMonths: [3, 4, 5, 9, 10, 11],
  ),

  RecommendDestination(
    id: 'hagiang',
    name: 'Ha Giang',
    shortDescription: 'Remote northern highlands with jaw-dropping mountain passes.',
    description:
        "Ha Giang is Vietnam's northernmost province, home to rugged karst landscapes, dramatic mountain passes, and the colorful cultures of ethnic minorities.",
    imagePath: 'https://picsum.photos/seed/hagiang/800/600',
    rating: 4.8,
    tags: ['Adventure', 'Nature', 'Off-the-beaten-path'],
    bestTimeTitle: 'October to April',
    bestTimeDetails: [
      'Dry season with clear visibility',
      'Buckwheat flowers bloom (Oct–Nov)',
      'Cool and comfortable trekking weather',
    ],
    activities: [
      'Ride the Ha Giang Loop motorbike circuit',
      'Visit Dong Van Karst Plateau Geopark',
      'Explore the Sunday market at Dong Van',
      'Hike to the Lung Cu Flag Tower',
    ],
    cuisine: [
      RecommendFood(
        name: 'Men Men (Corn Porridge)',
        imagePath: 'https://picsum.photos/seed/menmen/600/400',
      ),
      RecommendFood(
        name: 'Thit Trau Gac Bep (Smoked Buffalo)',
        imagePath: 'https://picsum.photos/seed/buffalo/600/400',
      ),
    ],
    tips: [
      'The Ha Giang Loop requires a valid motorbike license.',
      'Petrol stations are sparse — fill up at every opportunity.',
      'Hire a local Easy Rider guide for safety on mountain passes.',
    ],
    gallery: [
      'https://picsum.photos/seed/hagiang1/300/200',
      'https://picsum.photos/seed/hagiang2/300/200',
      'https://picsum.photos/seed/hagiang3/300/200',
    ],
    highlights:
        "The Ha Giang Loop is one of Southeast Asia's greatest motorbike adventures, winding through towering karst peaks, deep river valleys, and remote ethnic village communities.",
    bestMonths: [10, 11, 3, 4],
  ),

  RecommendDestination(
    id: 'haiphong',
    name: 'Hai Phong',
    shortDescription: 'Port city gateway to Cat Ba Island and Ha Long Bay.',
    description:
        "Hai Phong is Vietnam's third-largest city and a key port, serving as the gateway to Cat Ba Island. It's known for French colonial architecture and incredibly fresh seafood.",
    imagePath: 'https://picsum.photos/seed/haiphong/800/600',
    rating: 4.2,
    tags: ['History', 'Seafood', 'Islands'],
    bestTimeTitle: 'October to April',
    bestTimeDetails: [
      'Pleasant, dry weather',
      'Ideal for island hopping to Cat Ba',
      'Calm seas for boat tours',
    ],
    activities: [
      'Day trip to Cat Ba Island',
      'Kayak through Ha Long Bay',
      'Visit Do Son Beach',
      'Explore the Hang Kenh Communal House',
    ],
    cuisine: [
      RecommendFood(
        name: 'Banh Mi Hai Phong',
        imagePath: 'https://picsum.photos/seed/banhmi3/600/400',
      ),
      RecommendFood(
        name: 'Crab Roe Vermicelli (Bun Cua)',
        imagePath: 'https://picsum.photos/seed/buncua/600/400',
      ),
    ],
    tips: [
      'Book ferry tickets to Cat Ba in advance on weekends.',
      "The city's street food scene is underrated — explore the market areas.",
    ],
    gallery: [
      'https://picsum.photos/seed/haiphong1/300/200',
      'https://picsum.photos/seed/haiphong2/300/200',
      'https://picsum.photos/seed/haiphong3/300/200',
    ],
    highlights:
        "Hai Phong's blend of colonial history and sea-fresh cuisine makes it a hidden gem, while its position as the gateway to Cat Ba Island adds adventure.",
    bestMonths: [10, 11, 12, 1, 2, 3, 4],
  ),

  RecommendDestination(
    id: 'hatinh',
    name: 'Ha Tinh',
    shortDescription: 'Quiet coastal province with beautiful beaches and authentic local life.',
    description:
        'Ha Tinh is a central Vietnam coastal province with beautiful beaches, historic sites, and warm hospitality, offering an authentic off-the-tourist-trail experience.',
    imagePath: 'https://picsum.photos/seed/hatinh/800/600',
    rating: 4.1,
    tags: ['Beach', 'Local Life', 'History'],
    bestTimeTitle: 'April to August',
    bestTimeDetails: [
      'Hot, sunny beach weather',
      'Calm sea ideal for swimming',
      'Lively local beach culture',
    ],
    activities: [
      'Relax at Thien Cam Beach',
      'Visit Dong Loc Junction memorial',
      'Try local sea snail dishes at the market',
    ],
    cuisine: [
      RecommendFood(
        name: 'Sea Snails (Oc)',
        imagePath: 'https://picsum.photos/seed/oc/600/400',
      ),
      RecommendFood(
        name: 'Cu Do Cake',
        imagePath: 'https://picsum.photos/seed/cudo/600/400',
      ),
    ],
    tips: [
      'A motorbike is the best way to explore the coastal roads.',
      'Visit early morning for the most scenic beach atmosphere.',
    ],
    gallery: [
      'https://picsum.photos/seed/hatinh1/300/200',
      'https://picsum.photos/seed/hatinh2/300/200',
      'https://picsum.photos/seed/hatinh3/300/200',
    ],
    highlights:
        "Ha Tinh offers peaceful beaches, heartfelt history at Dong Loc Junction, and some of central Vietnam's most genuine local culinary experiences.",
    bestMonths: [4, 5, 6, 7, 8],
  ),
];
