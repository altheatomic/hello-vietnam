import 'package:flutter/material.dart';

class TripPlannerMockData {
  TripPlannerMockData._();

  static const List<TripPlannerDayData> tripDays = <TripPlannerDayData>[
    TripPlannerDayData(
      dayLabel: 'Day 1',
      date: 'Dec 5, 2025',
      activityCountLabel: '3 activities planned',
      moreActivitiesLabel: '+ 1 more activity',
      gradientColors: <Color>[
        Color(0xFFE9F0FD),
        Color(0xFFE7FAFD),
        Color(0xFFD6F7F6),
      ],
      activities: <TripPlannerActivityData>[
        TripPlannerActivityData(
          title: 'Temple of Literature Visit',
          time: '08:00',
          slot: 'Morning',
          tag: 'culture',
          description:
              "Explore Vietnam's first national university, a beautiful example of traditional Vietnamese architecture and Confucian heritage.",
          distanceLabel: 'Around 800 meters',
          lat: 21.0285,
          lng: 105.8357,
          tips: <String>[
            'Arrive early to avoid crowds',
            'Dress modestly for temple visit',
            'Photography allowed but be respectful',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Hospital 1',
              subtitle: 'Hospital',
              distance: '140m',
              eta: '2 mins',
              lat: 21.0287,
              lng: 105.8340,
            ),
            TripPlannerNearbyPlace(
              title: 'Hospital 2',
              subtitle: 'Hospital',
              distance: '450m',
              eta: '5 mins',
              lat: 21.0301,
              lng: 105.8372,
            ),
            TripPlannerNearbyPlace(
              title: 'Long Chau Pharmacy',
              subtitle: 'Pharmacy',
              distance: '680m',
              eta: '8 mins',
              lat: 21.0265,
              lng: 105.8390,
            ),
          ],
        ),
        TripPlannerActivityData(
          title: 'Old Quarter Street Food Tour',
          time: '12:00',
          slot: 'Lunch',
          tag: 'culture',
          description:
              "Discover authentic Vietnamese cuisine through a guided tour of Hanoi's famous Old Quarter, sampling local delicacies.",
          distanceLabel: 'Around 1.2 kilometers',
          tips: <String>[
            'Come hungry!',
            'Bring cash for street vendors',
            'Try the famous pho and banh mi',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Pho Counter',
              subtitle: 'Restaurant',
              distance: '210m',
              eta: '3 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Local Market',
              subtitle: 'Shopping',
              distance: '480m',
              eta: '6 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Cafe Lantern',
              subtitle: 'Cafe',
              distance: '750m',
              eta: '9 mins',
            ),
          ],
        ),
        TripPlannerActivityData(
          title: 'Hoan Kiem Lake & NS Temple',
          time: '17:00',
          slot: 'Afternoon',
          tag: 'culture',
          description:
              'Visit the iconic Hoan Kiem Lake and Ngoc Son Temple, a peaceful retreat in the heart of Hanoi.',
          distanceLabel: 'Around 650 meters',
          tips: <String>[
            'Perfect for sunset photos',
            'Watch locals exercise around the lake',
            'Visit the temple for beautiful views',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Water Puppet Theater',
              subtitle: 'Entertainment',
              distance: '170m',
              eta: '2 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Trang Tien Plaza',
              subtitle: 'Shopping',
              distance: '520m',
              eta: '7 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Lakeside Cafe',
              subtitle: 'Cafe',
              distance: '610m',
              eta: '8 mins',
            ),
          ],
        ),
      ],
    ),
    TripPlannerDayData(
      dayLabel: 'Day 2',
      date: 'Dec 6, 2025',
      activityCountLabel: '3 activities planned',
      moreActivitiesLabel: '+ 1 more activity',
      gradientColors: <Color>[
        Color(0xFFEAF0FD),
        Color(0xFFF0FAFC),
        Color(0xFFD8F4F1),
      ],
      activities: <TripPlannerActivityData>[
        TripPlannerActivityData(
          title: 'Ha Long Bay Cruise Departure',
          time: '07:00',
          slot: 'Morning',
          tag: 'adventure',
          description:
              'Set off early for a scenic cruise into Ha Long Bay, passing limestone karsts and hidden coves.',
          distanceLabel: 'Around 1.1 kilometers',
          tips: <String>[
            'Keep a light jacket for the morning breeze',
            'Charge your phone before boarding',
            'Bring water and sunscreen',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Pier Shuttle',
              subtitle: 'Transport',
              distance: '300m',
              eta: '4 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Bay Cafe',
              subtitle: 'Cafe',
              distance: '500m',
              eta: '6 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Harbor Pharmacy',
              subtitle: 'Pharmacy',
              distance: '720m',
              eta: '9 mins',
            ),
          ],
        ),
        TripPlannerActivityData(
          title: 'Seafood Lunch on Boat',
          time: '12:00',
          slot: 'Lunch',
          tag: 'food',
          description:
              'Enjoy fresh seafood on board while cruising through the emerald waters of the bay.',
          distanceLabel: 'Around 900 meters',
          tips: <String>[
            'Ask crew for vegetarian alternatives if needed',
            'Keep valuables in a dry bag',
            'Try the local squid specialty',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Floating Dock',
              subtitle: 'Transport',
              distance: '260m',
              eta: '3 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Seafood Market',
              subtitle: 'Shopping',
              distance: '530m',
              eta: '7 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Harbor Clinic',
              subtitle: 'Clinic',
              distance: '830m',
              eta: '10 mins',
            ),
          ],
        ),
        TripPlannerActivityData(
          title: 'Cave Exploration & Kayaking',
          time: '15:00',
          slot: 'Afternoon',
          tag: 'adventure',
          description:
              'Paddle through quiet lagoons and discover hidden caves carved into the bay over centuries.',
          distanceLabel: 'Around 1.4 kilometers',
          tips: <String>[
            'Wear sandals with grip',
            'Listen closely to the safety briefing',
            'Store electronics in waterproof pouches',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Kayak Dock',
              subtitle: 'Adventure',
              distance: '220m',
              eta: '3 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Locker Point',
              subtitle: 'Service',
              distance: '470m',
              eta: '6 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'First Aid Cabin',
              subtitle: 'Medical',
              distance: '760m',
              eta: '9 mins',
            ),
          ],
        ),
      ],
    ),
    TripPlannerDayData(
      dayLabel: 'Day 3',
      date: 'Dec 7, 2025',
      activityCountLabel: '3 activities planned',
      moreActivitiesLabel: '+ 1 more activity',
      gradientColors: <Color>[
        Color(0xFFE7FBF7),
        Color(0xFFF0FAFC),
        Color(0xFFD8F6F0),
      ],
      activities: <TripPlannerActivityData>[
        TripPlannerActivityData(
          title: 'Sunrise Tai Chi & Breakfast',
          time: '06:30',
          slot: 'Morning',
          tag: 'wellness',
          description:
              'Start the day with a gentle tai chi session and a peaceful breakfast overlooking the city.',
          distanceLabel: 'Around 500 meters',
          tips: <String>[
            'Wear comfortable, breathable clothes',
            'Bring a bottle of water',
            'Arrive 10 minutes early',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Breakfast Spot',
              subtitle: 'Cafe',
              distance: '120m',
              eta: '2 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Garden Deck',
              subtitle: 'Wellness',
              distance: '380m',
              eta: '5 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Mini Mart',
              subtitle: 'Shopping',
              distance: '620m',
              eta: '8 mins',
            ),
          ],
        ),
        TripPlannerActivityData(
          title: 'Spa',
          time: '10:00',
          slot: 'Late Morning',
          tag: 'relax',
          description:
              'Recharge with a traditional spa treatment designed to help you relax before the trip wraps up.',
          distanceLabel: 'Around 350 meters',
          tips: <String>[
            'Arrive without heavy luggage',
            'Request your preferred massage pressure',
            'Keep valuables locked safely',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Tea Lounge',
              subtitle: 'Cafe',
              distance: '150m',
              eta: '2 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Spa Reception',
              subtitle: 'Service',
              distance: '330m',
              eta: '4 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Wellness Shop',
              subtitle: 'Shopping',
              distance: '590m',
              eta: '7 mins',
            ),
          ],
        ),
        TripPlannerActivityData(
          title: 'Shopping at Xuan Market',
          time: '16:00',
          slot: 'Afternoon',
          tag: 'entertainment',
          description:
              'Pick up souvenirs and local specialties at one of Hanoi\'s busiest markets before heading home.',
          distanceLabel: 'Around 1 kilometer',
          tips: <String>[
            'Bargain politely',
            'Carry small cash bills',
            'Check fragile goods before buying',
          ],
          nearbyPlaces: <TripPlannerNearbyPlace>[
            TripPlannerNearbyPlace(
              title: 'Souvenir Row',
              subtitle: 'Shopping',
              distance: '140m',
              eta: '2 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'ATM Point',
              subtitle: 'Service',
              distance: '400m',
              eta: '5 mins',
            ),
            TripPlannerNearbyPlace(
              title: 'Coffee Corner',
              subtitle: 'Cafe',
              distance: '660m',
              eta: '8 mins',
            ),
          ],
        ),
      ],
    ),
  ];

  static TripPlannerDayData dayAt(int index) {
    if (index < 0 || index >= tripDays.length) {
      return tripDays.first;
    }
    return tripDays[index];
  }

  static TripPlannerActivityData activityAt(int dayIndex, int activityIndex) {
    final TripPlannerDayData day = dayAt(dayIndex);
    if (activityIndex < 0 || activityIndex >= day.activities.length) {
      return day.activities.first;
    }
    return day.activities[activityIndex];
  }
}

class TripPlannerDayData {
  const TripPlannerDayData({
    required this.dayLabel,
    required this.date,
    required this.activityCountLabel,
    required this.moreActivitiesLabel,
    required this.activities,
    required this.gradientColors,
  });

  final String dayLabel;
  final String date;
  final String activityCountLabel;
  final String moreActivitiesLabel;
  final List<TripPlannerActivityData> activities;
  final List<Color> gradientColors;

  Map<String, dynamic> toJson() => {
        'dayLabel': dayLabel,
        'date': date,
        'activityCountLabel': activityCountLabel,
        'moreActivitiesLabel': moreActivitiesLabel,
        'activities': activities.map((a) => a.toJson()).toList(),
        'gradientColors': gradientColors.map((c) => c.toARGB32()).toList(),
      };

  factory TripPlannerDayData.fromJson(Map<String, dynamic> json) =>
      TripPlannerDayData(
        dayLabel: json['dayLabel'] as String,
        date: json['date'] as String,
        activityCountLabel: json['activityCountLabel'] as String,
        moreActivitiesLabel: json['moreActivitiesLabel'] as String,
        activities: (json['activities'] as List)
            .map((j) => TripPlannerActivityData.fromJson(j as Map<String, dynamic>))
            .toList(),
        gradientColors: (json['gradientColors'] as List)
            .map((v) => Color(v as int))
            .toList(),
      );
}

class TripPlannerActivityData {
  const TripPlannerActivityData({
    required this.title,
    required this.time,
    required this.slot,
    required this.tag,
    this.tags = const <String>[],
    required this.description,
    required this.distanceLabel,
    required this.tips,
    required this.nearbyPlaces,
    this.lat = 0.0,
    this.lng = 0.0,
    this.imageUrl,
    this.idPlace = '',
    this.idProvince = '',
    this.estimatedDurationMinutes,
    this.travelTimeCarSeconds,
    this.travelTimeBikeSeconds,
    this.travelDistanceCarMeters,
    this.travelDistanceBikeMeters,
    this.minimumPrice,
    this.maximumPrice,
    this.timespan,
    this.timeclose,
  });

  final String title;
  final String time;
  final String slot;
  /// Sentinel discriminator — 'lunch_break' for synthetic lunch entries,
  /// otherwise unused for display (see [tags] for the place's real category
  /// chips). Kept as-is: still load-bearing for the `a.tag != 'lunch_break'`
  /// filters in trip_day_detail_page.dart and trip_result_page.dart.
  final String tag;
  /// The place's own real tag_name list (place_tag rows above the backend's
  /// confidence threshold — see cf_service _extract_place_tag_names()), NOT
  /// a per-user match. Always a list, empty if the place has no qualifying
  /// tag. This is what the category chip row should render from.
  final List<String> tags;
  final String description;
  final String distanceLabel;
  final List<String> tips;
  final List<TripPlannerNearbyPlace> nearbyPlaces;
  final double lat;
  final double lng;
  final String? imageUrl;
  final String idPlace;
  final String idProvince;
  final int? estimatedDurationMinutes;
  /// Goong Distance Matrix data for the edge FROM the previous activity TO
  /// this one. Null for the first activity of the day / uncovered edges.
  final int? travelTimeCarSeconds;
  final int? travelTimeBikeSeconds;
  final int? travelDistanceCarMeters;
  final int? travelDistanceBikeMeters;
  final num? minimumPrice;
  final num? maximumPrice;
  final String? timespan;
  final String? timeclose;

  Map<String, dynamic> toJson() => {
        'title': title,
        'time': time,
        'slot': slot,
        'tag': tag,
        'tags': tags,
        'description': description,
        'distanceLabel': distanceLabel,
        'tips': tips,
        'nearbyPlaces': nearbyPlaces.map((p) => p.toJson()).toList(),
        'lat': lat,
        'lng': lng,
        'imageUrl': imageUrl,
        'idPlace': idPlace,
        'idProvince': idProvince,
        'estimatedDurationMinutes': estimatedDurationMinutes,
        'travelTimeCarSeconds': travelTimeCarSeconds,
        'travelTimeBikeSeconds': travelTimeBikeSeconds,
        'travelDistanceCarMeters': travelDistanceCarMeters,
        'travelDistanceBikeMeters': travelDistanceBikeMeters,
        'minimumPrice': minimumPrice,
        'maximumPrice': maximumPrice,
        'timespan': timespan,
        'timeclose': timeclose,
      };

  factory TripPlannerActivityData.fromJson(Map<String, dynamic> json) =>
      TripPlannerActivityData(
        title: json['title'] as String,
        time: json['time'] as String,
        slot: json['slot'] as String,
        tag: json['tag'] as String,
        tags: json['tags'] is List
            ? List<String>.from(json['tags'] as List)
            : const <String>[],
        description: json['description'] as String,
        distanceLabel: json['distanceLabel'] as String,
        tips: List<String>.from(json['tips'] as List),
        nearbyPlaces: (json['nearbyPlaces'] as List)
            .map((j) => TripPlannerNearbyPlace.fromJson(j as Map<String, dynamic>))
            .toList(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String?,
        idPlace: json['idPlace'] as String? ?? '',
        idProvince: json['idProvince'] as String? ?? '',
        estimatedDurationMinutes:
            (json['estimatedDurationMinutes'] as num?)?.toInt(),
        travelTimeCarSeconds: (json['travelTimeCarSeconds'] as num?)?.toInt(),
        travelTimeBikeSeconds: (json['travelTimeBikeSeconds'] as num?)?.toInt(),
        travelDistanceCarMeters:
            (json['travelDistanceCarMeters'] as num?)?.toInt(),
        travelDistanceBikeMeters:
            (json['travelDistanceBikeMeters'] as num?)?.toInt(),
        minimumPrice: json['minimumPrice'] as num?,
        maximumPrice: json['maximumPrice'] as num?,
        timespan: json['timespan'] as String?,
        timeclose: json['timeclose'] as String?,
      );
}

class TripPlannerNearbyPlace {
  const TripPlannerNearbyPlace({
    required this.title,
    required this.subtitle,
    required this.distance,
    required this.eta,
    this.lat = 0.0,
    this.lng = 0.0,
  });

  final String title;
  final String subtitle;
  final String distance;
  final String eta;
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'distance': distance,
        'eta': eta,
        'lat': lat,
        'lng': lng,
      };

  factory TripPlannerNearbyPlace.fromJson(Map<String, dynamic> json) =>
      TripPlannerNearbyPlace(
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        distance: json['distance'] as String,
        eta: json['eta'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}
