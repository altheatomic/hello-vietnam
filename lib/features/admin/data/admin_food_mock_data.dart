import '../domain/admin_food.dart';

/// Mock food records for the admin food management table.
///
/// 10 entries across various types and cities, exercising the filter chips
/// and pagination footer.
final List<AdminFood> mockAdminFoods = [
  const AdminFood(
    id: 'food-001',
    name: 'Phở Bò',
    typeId: 'noodles',
    city: 'Hanoi',
    urlImage: 'https://picsum.photos/seed/pho/80/80',
    description:
        'Iconic Vietnamese beef noodle soup with aromatic broth, rice noodles, and fresh herbs.',
  ),
  const AdminFood(
    id: 'food-002',
    name: 'Bánh Mì',
    typeId: 'street-food',
    city: 'Ho Chi Minh City',
    urlImage: 'https://picsum.photos/seed/banhmi/80/80',
    description:
        'Crispy baguette stuffed with pâté, cold cuts, pickled vegetables, and fresh chilli.',
  ),
  const AdminFood(
    id: 'food-003',
    name: 'Cơm Tấm',
    typeId: 'rice',
    city: 'Ho Chi Minh City',
    urlImage: 'https://picsum.photos/seed/comtam/80/80',
    description:
        'Broken rice served with grilled pork chop, egg, shredded pork skin, and fish sauce.',
  ),
  const AdminFood(
    id: 'food-004',
    name: 'Bún Bò Huế',
    typeId: 'noodles',
    city: 'Hue',
    urlImage: 'https://picsum.photos/seed/bunbohue/80/80',
    description:
        'Spicy lemongrass beef noodle soup from the old imperial capital Hue.',
  ),
  const AdminFood(
    id: 'food-005',
    name: 'Bún Chả',
    typeId: 'grilled',
    city: 'Hanoi',
    urlImage: 'https://picsum.photos/seed/buncha/80/80',
    description:
        'Grilled pork patties and belly served with vermicelli, fresh herbs, and dipping sauce.',
  ),
  const AdminFood(
    id: 'food-006',
    name: 'Cao Lầu',
    typeId: 'noodles',
    city: 'Hoi An',
    urlImage: 'https://picsum.photos/seed/caolau/80/80',
    description:
        'Thick chewy noodles with char siu pork, crispy croutons, and bean sprouts.',
  ),
  const AdminFood(
    id: 'food-007',
    name: 'Chè Ba Màu',
    typeId: 'dessert',
    city: 'Ho Chi Minh City',
    urlImage: 'https://picsum.photos/seed/che/80/80',
    description:
        'Three-colour sweet dessert with mung beans, red beans, pandan jelly, and coconut milk.',
  ),
  const AdminFood(
    id: 'food-008',
    name: 'Cà Phê Trứng',
    typeId: 'drinks',
    city: 'Hanoi',
    urlImage: 'https://picsum.photos/seed/eggcoffee/80/80',
    description:
        'Hanoi egg coffee — a thick, creamy egg yolk foam poured over strong Vietnamese drip coffee.',
  ),
  const AdminFood(
    id: 'food-009',
    name: 'Mì Quảng',
    typeId: 'noodles',
    city: 'Da Nang',
    urlImage: 'https://picsum.photos/seed/miquang/80/80',
    description:
        'Wide turmeric rice noodles with a small amount of rich broth, shrimp, pork, and peanuts.',
  ),
  const AdminFood(
    id: 'food-010',
    name: 'Bánh Xèo',
    typeId: 'street-food',
    city: 'Da Nang',
    urlImage: 'https://picsum.photos/seed/banhxeo/80/80',
    description:
        'Sizzling crispy rice-flour crepe stuffed with shrimp, pork, and bean sprouts.',
  ),
];
